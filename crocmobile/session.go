package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/schollz/croc/v10/src/croc"
	"github.com/schollz/croc/v10/src/utils"
)

// One transfer at a time: croc needs process-global os.Chdir/os.Stdin/os.Stdout.
var activeMu sync.Mutex

type session struct {
	client    *croc.Client
	ctxCancel context.CancelFunc
	delegate  Delegate

	sender   bool
	tempPath string   // absolute path of the text-send temp file, if any; removed in run()
	promptW  *os.File // write end of the stdin pipe; nil once closed
	promptM  sync.Mutex

	restoreIO func() // receive only: restore os.Stdin/os.Stdout, drain capture

	stdoutBuf []byte // captured os.Stdout (text receive)
	stdoutM   sync.Mutex

	done chan struct{}
}

func buildCrocOptions(sender bool, secret string, o *Options) croc.Options {
	return croc.Options{
		IsSender:         sender,
		SharedSecret:     secret,
		RelayAddress:     o.RelayAddress,
		RelayAddress6:    o.RelayAddress6,
		RelayPassword:    o.RelayPassword,
		RelayPorts:       splitNonEmpty(o.RelayPorts, ","),
		Curve:            o.Curve,
		HashAlgorithm:    o.HashAlgorithm,
		ThrottleUpload:   o.ThrottleUpload,
		DisableLocal:     o.DisableLocal,
		OnlyLocal:        o.OnlyLocal,
		NoCompress:       o.NoCompress,
		ZipFolder:        o.ZipFolder,
		GitIgnore:        o.GitIgnore,
		Exclude:          splitNonEmpty(o.Exclude, "\n"),
		Overwrite:        o.Overwrite,
		NoPrompt:         sender || o.AutoAccept, // sender-side prompts only exist for Ask
		Ask:              o.Ask,
		NoMultiplexing:   o.NoMultiplexing,
		IgnoreStdin:      true,
		DisableClipboard: true,
		Quiet:            false, // Quiet=true nukes process stderr globally
	}
}

func splitNonEmpty(s, sep string) []string {
	var out []string
	for _, p := range strings.Split(s, sep) {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// startSession acquires the process-global lock, does the synchronous setup
// for a transfer, and (on success) hands the lock off to the async s.run
// goroutine which releases it when the transfer finishes.
//
// The deferred cleanup below fires whenever startSession returns or panics
// without having committed to an async run — every error path, any panic
// from croc.GetFilesInfoWithExactExclusions/croc.NewCtx, and (because
// `committed` is only set true right before the `go s.run(...)` call, after
// d.OnCodeReady returns) any panic raised by the delegate's OnCodeReady
// itself. This is what guarantees the lock, cwd, and temp file are never
// leaked, even across a panic. The panic itself is left to propagate to
// StartSend/StartReceive's own recover, which converts it into a returned
// error.
func startSession(sender bool, code string, paths []string, text string, o *Options, d Delegate) (*session, error) {
	if !activeMu.TryLock() {
		return nil, errors.New("another transfer is active")
	}
	origWD, _ := os.Getwd()
	committed := false
	defer func() {
		if !committed {
			os.Chdir(origWD)
			activeMu.Unlock()
		}
	}()

	if sender {
		secret := o.Code
		if secret == "" {
			secret = utils.GetRandomName()
		}
		if len(secret) < 6 {
			return nil, errors.New("code is too short (must be at least 6 characters)")
		}
		if o.WorkDir != "" {
			if err := os.Chdir(o.WorkDir); err != nil {
				return nil, fmt.Errorf("workdir: %w", err)
			}
		}
		var tempPath string
		if text != "" {
			f, err := os.CreateTemp(".", "croc-stdin-*")
			if err != nil {
				return nil, err
			}
			if _, err := f.WriteString(text); err != nil {
				f.Close()
				os.Remove(f.Name())
				return nil, err
			}
			f.Close()
			// Resolve to an absolute path now: run() may remove this file
			// after cwd has already been restored to origWD.
			if abs, err := filepath.Abs(f.Name()); err == nil {
				tempPath = abs
			} else {
				tempPath = f.Name()
			}
			paths = []string{f.Name()}
		}
		filesInfo, emptyFolders, totalFolders, err := croc.GetFilesInfoWithExactExclusions(
			paths, o.ZipFolder, o.GitIgnore, splitNonEmpty(o.Exclude, "\n"), nil)
		if err != nil {
			if tempPath != "" {
				os.Remove(tempPath)
			}
			return nil, err
		}
		co := buildCrocOptions(true, secret, o)
		co.SendingText = text != ""
		ctx, cancel := context.WithCancel(context.Background())
		c, err := croc.NewCtx(ctx, co)
		if err != nil {
			cancel()
			if tempPath != "" {
				os.Remove(tempPath)
			}
			return nil, err
		}
		s := &session{client: c, ctxCancel: cancel, delegate: d, sender: true, tempPath: tempPath, done: make(chan struct{})}
		// OnCodeReady runs before we commit: if the delegate panics here, the
		// cleanup defer above must still be armed to release the lock, cwd,
		// and temp file, rather than leaking them because we'd already
		// (wrongly) considered the async run started.
		d.OnCodeReady(secret)
		committed = true
		go s.run(func() error { return c.Send(filesInfo, emptyFolders, totalFolders) }, origWD, func() { activeMu.Unlock() })
		go s.poll()
		return s, nil
	}
	return startReceiveSession(code, o, d, origWD, &committed)
}

// startReceiveSession is startSession's receive-side counterpart, called as a
// tail call from within startSession's own frame: the `committed` guard defer
// declared there is still armed for every error path below, so on failure we
// only need to unwind whatever this function itself set up (pipes, os.Stdin/
// os.Stdout swaps, the croc ctx) — cwd restore and the activeMu unlock are
// handled by that defer once we return. Only right before the async run
// actually starts do we flip *committed to true, handing ownership of cwd
// and the lock to s.run/release.
func startReceiveSession(code string, o *Options, d Delegate, origWD string, committed *bool) (*session, error) {
	outDir := o.OutDir
	if outDir == "" {
		return nil, errors.New("OutDir required for receive")
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return nil, err
	}
	if err := os.Chdir(outDir); err != nil {
		return nil, err
	}

	co := buildCrocOptions(false, code, o)
	ctx, cancel := context.WithCancel(context.Background())
	c, err := croc.NewCtx(ctx, co)
	if err != nil {
		cancel()
		return nil, err
	}
	s := &session{client: c, ctxCancel: cancel, delegate: d, sender: false, done: make(chan struct{})}

	// Accept/decline prompt bridge: croc reads the answer via
	// utils.GetInput, which reads a bufio.Reader created once, at package
	// init, wrapping the real fd 0 -- reassigning the os.Stdin *variable*
	// later has no effect on that already-built reader. So beyond swapping
	// the variable (for anything that does read it fresh), dup2 the pipe's
	// read end onto fd 0 itself so the cached reader also pulls from our
	// pipe. With AutoAccept the accept prompt is skipped, so close
	// immediately: any un-gated prompt (empty folder, unzip overwrite) then
	// hits EOF -> safe default, no hang.
	pr, pw, err := os.Pipe()
	if err != nil {
		cancel()
		return nil, err
	}
	savedStdinFd, err := syscall.Dup(syscall.Stdin)
	if err != nil {
		pr.Close()
		pw.Close()
		cancel()
		return nil, err
	}
	if err := syscall.Dup2(int(pr.Fd()), syscall.Stdin); err != nil {
		syscall.Close(savedStdinFd)
		pr.Close()
		pw.Close()
		cancel()
		return nil, err
	}
	origStdin := os.Stdin
	os.Stdin = pr
	s.promptW = pw
	if o.AutoAccept {
		s.closePrompt()
	}

	// Text transfers stream to os.Stdout; capture it.
	cr, cw, err := os.Pipe()
	if err != nil {
		os.Stdin = origStdin
		syscall.Dup2(savedStdinFd, syscall.Stdin)
		syscall.Close(savedStdinFd)
		s.closePrompt() // closes pw unless AutoAccept already did
		pr.Close()
		cancel()
		return nil, err
	}
	origStdout := os.Stdout
	os.Stdout = cw
	captureDone := make(chan struct{})
	go func() {
		defer close(captureDone)
		defer func() { recover() }() // gobind: a goroutine panic kills the host app
		buf := make([]byte, 32*1024)
		for {
			n, err := cr.Read(buf)
			if n > 0 {
				s.stdoutM.Lock()
				if len(s.stdoutBuf) < 10*1024*1024 { // cap: text snippets only
					s.stdoutBuf = append(s.stdoutBuf, buf[:n]...)
				}
				s.stdoutM.Unlock()
			}
			if err != nil {
				return
			}
		}
	}()
	s.restoreIO = func() {
		os.Stdin = origStdin
		os.Stdout = origStdout
		cw.Close()
		<-captureDone
		cr.Close()
		syscall.Dup2(savedStdinFd, syscall.Stdin)
		syscall.Close(savedStdinFd)
		pr.Close()
	}

	*committed = true
	go s.run(func() error { return c.Receive() }, origWD, func() { activeMu.Unlock() })
	go s.poll()
	return s, nil
}

// run executes the transfer, then restores globals and reports the outcome.
func (s *session) run(xfer func() error, origWD string, release func()) {
	var err error
	func() {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("croc panic: %v", r)
			}
		}()
		err = xfer()
	}()
	close(s.done)
	s.closePrompt()
	text := s.finishStdoutCapture()
	if s.tempPath != "" {
		os.Remove(s.tempPath)
	}
	os.Chdir(origWD)
	release()
	if err != nil {
		s.delegate.OnError(err.Error())
		return
	}
	if text != "" {
		s.delegate.OnText(text)
	}
	s.delegate.OnDone(s.summaryJSON())
}

// cancel must unblock a pending accept prompt, not just cancel the context:
// croc's transfer goroutine blocks in GetInput reading our prompt pipe when
// waiting on the receiver to accept/decline, and ctx cancellation alone does
// not interrupt that read. Without closePrompt here, that goroutine stays
// blocked forever, Receive() never returns, run() never releases activeMu,
// and the whole engine is bricked. closePrompt is idempotent and nil-guarded
// (already a no-op for senders, or once respond() has run), so it's always
// safe to call: closing the pipe here makes GetInput hit EOF, croc refuses
// the files, and Receive() returns normally through run()'s existing cleanup.
func (s *session) cancel() {
	s.ctxCancel()
	s.closePrompt()
}

func (s *session) respond(accept bool) {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW == nil {
		return
	}
	if accept {
		_, _ = s.promptW.WriteString("y\n")
	} else {
		_, _ = s.promptW.WriteString("n\n")
	}
	// Close so any later un-gated prompt (empty-folder, unzip overwrite)
	// hits EOF and takes its safe default instead of hanging.
	s.promptW.Close()
	s.promptW = nil
}

func (s *session) closePrompt() {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW != nil {
		s.promptW.Close()
		s.promptW = nil
	}
}

// finishStdoutCapture restores IO globals and returns captured text if this
// was a text transfer (croc sets Options.Stdout on the receiver for those).
func (s *session) finishStdoutCapture() string {
	if s.restoreIO == nil {
		return ""
	}
	s.restoreIO()
	s.restoreIO = nil
	if !s.client.Options.Stdout || s.sender {
		return ""
	}
	s.stdoutM.Lock()
	defer s.stdoutM.Unlock()
	return strings.TrimRight(string(s.stdoutBuf), "\n")
}

// poll translates Client fields into delegate events at 10 Hz.
// Transfers that complete within a single tick (e.g. a few bytes over a fast
// local connection) can race s.done and skip an intermediate OnConnected or
// OnProgress call entirely — OnDone still fires reliably.
func (s *session) poll() {
	defer func() { recover() }() // racy field reads must never crash the app
	t := time.NewTicker(100 * time.Millisecond)
	defer t.Stop()
	connected, listSent := false, false
	for {
		select {
		case <-s.done:
			return
		case <-t.C:
		}
		c := s.client
		if !connected && c.Step1ChannelSecured {
			connected = true
			s.delegate.OnConnected()
		}
		if !s.sender && !listSent && len(c.FilesToTransfer) > 0 {
			listSent = true
			s.delegate.OnFileList(s.fileListJSON())
		}
		s.delegate.OnProgress(s.progressJSON(connected))
	}
}

type fileEntry struct {
	Name string `json:"name"`
	Size int64  `json:"size"`
}

func (s *session) fileListJSON() string {
	c := s.client
	var files []fileEntry
	var total int64
	for _, f := range c.FilesToTransfer {
		name := filepath.Join(f.FolderRemote, f.Name)
		files = append(files, fileEntry{Name: name, Size: f.Size})
		total += f.Size
	}
	b, _ := json.Marshal(map[string]any{
		"files": files, "emptyFolders": len(c.EmptyFoldersToTransfer), "totalSize": total,
	})
	return string(b)
}

func (s *session) progressJSON(connected bool) string {
	c := s.client
	step := "waiting"
	if connected {
		step = "connected"
	}
	cur := c.FilesToTransferCurrentNum // racy int read is benign on arm64
	var fileName string
	var fileSize, totalSize, bytesFinished int64
	// Sum sizes of files strictly before the current one instead of indexing
	// c.FilesHasFinished: that map is written unguarded by croc's own
	// goroutines, and a concurrent read here races it -- a fatal, unrecoverable
	// runtime throw, not a panic recover() can catch.
	for i, f := range c.FilesToTransfer {
		totalSize += f.Size
		if i < cur {
			bytesFinished += f.Size
		}
	}
	if cur >= 0 && cur < len(c.FilesToTransfer) {
		f := c.FilesToTransfer[cur]
		fileName = f.Name
		fileSize = f.Size
	}
	sent := c.TotalSent // per-current-file
	if c.Step3RecipientRequestFile || sent > 0 {
		step = "transferring"
	}
	b, _ := json.Marshal(map[string]any{
		"currentFile": cur, "totalFiles": len(c.FilesToTransfer), "fileName": fileName,
		"fileSent": sent, "fileSize": fileSize, "bytesFinished": bytesFinished,
		"totalSize": totalSize, "step": step,
	})
	return string(b)
}

func (s *session) summaryJSON() string {
	c := s.client
	var total int64
	for _, f := range c.FilesToTransfer {
		total += f.Size
	}
	b, _ := json.Marshal(map[string]any{
		"success": c.SuccessfulTransfer, "files": len(c.FilesToTransfer), "totalSize": total,
	})
	return string(b)
}
