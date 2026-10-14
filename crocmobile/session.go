package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/schollz/croc/v11/src/codephrase"
	"github.com/schollz/croc/v11/src/croc"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/tcp"
	"github.com/schollz/croc/v11/src/utils"
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
	// promptAnswers: how many "y\n" lines an accept writes to promptW. croc's
	// sender-side Ask prompt (TypeRecipientReady handler, croc.go) fires once
	// PER FILE, so a single answer starves every prompt after the first and
	// croc aborts with "refusing files". Set to len(filesInfo) (floor 1) in
	// the sender Ask branch of startSession; left at the zero value (treated
	// as 1 by respond) everywhere else, since the receiver's accept/decline
	// prompt only fires once per transfer.
	promptAnswers int

	restoreIO func() // restore os.Stdin (sender Ask) or os.Stdin/os.Stdout+capture (receive)

	stdoutBuf []byte // captured os.Stdout (text receive)
	stdoutM   sync.Mutex

	done     chan struct{}
	pollDone chan struct{} // closed when poll() returns; run() waits on it before the terminal delegate calls
}

func buildCrocOptions(sender bool, secret string, o *Options) (croc.Options, error) {
	route, err := resolveRelay(secret, o)
	if err != nil {
		return croc.Options{}, err
	}
	transport, err := sessionTransport(sender, o)
	if err != nil {
		return croc.Options{}, err
	}
	password := o.RelayPassword
	if password == "" {
		password = models.DEFAULT_PASSPHRASE
	}
	co := croc.Options{
		IsSender:         sender,
		SharedSecret:     secret,
		RelayAddress:     route.v4,
		RelayAddress6:    route.v6,
		PublicRelay:      route.public,
		RelayPassword:    password,
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
		NoPrompt:         sender || o.AutoAccept, // sender-side prompts only exist for Ask
		Ask:              o.Ask,
		NoMultiplexing:   o.NoMultiplexing,
		IgnoreStdin:      true,
		DisableClipboard: true,
		Quiet:            false, // Quiet=true nukes process stderr globally
		Transport:        transport,
	}
	optionsPolicy(o).apply(&co)
	return co, nil
}

// sessionTransport is auto wherever croc refuses anything else: on a receive,
// which follows the sender, and on a local-only send.
func sessionTransport(sender bool, o *Options) (croc.TransportMode, error) {
	if !sender || o.OnlyLocal {
		return croc.TransportAuto, nil
	}
	return croc.ParseTransportMode(o.Transport)
}

// filePolicy decides what a receive does with a file whose name already
// exists. croc itself has a third state, Rename and Overwrite both false, in
// which it prompts on stdin; on our closed pipe that prompt skips the file,
// and on an unzip it aborts the transfer, so it is never passed to croc.
type filePolicy int

const (
	keepBoth filePolicy = iota
	replace
)

// promptPolicyAnswers is how many answers to croc's per-file stdin prompts a
// receive queues: the empty-folder prompt and the unzip "Overwrite '<path>'?
// (y/N)" prompt, which ignore Rename and Overwrite. Past that many collisions
// an unzip hits EOF and fails, leaving the received zip. 4096 two-byte lines
// fit a fresh pipe's buffer on Darwin and Linux, so the write never blocks,
// which startReceiveSession relies on for AutoAccept.
const promptPolicyAnswers = 4096

func parsePolicy(s string) filePolicy {
	if s == PolicyReplace {
		return replace
	}
	return keepBoth
}

func optionsPolicy(o *Options) filePolicy {
	if o.Overwrite && !o.Rename {
		return replace
	}
	return keepBoth
}

func (p filePolicy) apply(co *croc.Options) {
	co.Rename = p == keepBoth
	co.Overwrite = p == replace
}

// promptAnswers is the batch of answers croc's per-file prompts read: "y"
// replaces, "n" keeps what exists (the unzip skips that member).
func (p filePolicy) promptAnswers() string {
	answer := "n\n"
	if p == replace {
		answer = "y\n"
	}
	return strings.Repeat(answer, promptPolicyAnswers)
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
	origWD, err := os.Getwd()
	if err != nil {
		activeMu.Unlock()
		return nil, fmt.Errorf("working directory: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			removeTempFiles()
			restoreWD(origWD)
			activeMu.Unlock()
		}
	}()

	if sender {
		secret := o.Code
		generatedPublic := secret == "" && usesPublicRelay(o)
		if secret == "" {
			var err error
			if generatedPublic {
				secret, err = generatePublicCode(tcp.MeasureServerLatencyContext)
			} else {
				secret, err = codephrase.Generate()
			}
			if err != nil {
				return nil, fmt.Errorf("could not generate code phrase: %w", err)
			}
		}
		if len(secret) < minCodeLength {
			return nil, fmt.Errorf("code is too short (must be at least %d characters)", minCodeLength)
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
		co, err := buildCrocOptions(true, secret, o)
		if err != nil {
			if tempPath != "" {
				os.Remove(tempPath)
			}
			return nil, err
		}
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
		s := &session{client: c, ctxCancel: cancel, delegate: d, sender: true, tempPath: tempPath, done: make(chan struct{}), pollDone: make(chan struct{})}
		// OnCodeReady runs before we commit: if the delegate panics here, the
		// cleanup defer above must still be armed to release the lock, cwd,
		// and temp file, rather than leaking them because we'd already
		// (wrongly) considered the async run started.
		d.OnCodeReady(secret)
		if o.Ask {
			restore, rerr := s.installPromptPipe()
			if rerr != nil {
				cancel()
				if tempPath != "" {
					os.Remove(tempPath)
				}
				return nil, rerr
			}
			s.restoreIO = restore
			s.promptAnswers = len(filesInfo)
			if s.promptAnswers < 1 {
				s.promptAnswers = 1
			}
		}
		committed = true
		go s.run(func() error {
			err := c.Send(filesInfo, emptyFolders, totalFolders)
			if generatedPublic && errors.Is(err, croc.ErrRelayConnection) {
				forgetPublicRelay()
			}
			return err
		}, origWD, func() { activeMu.Unlock() })
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

	co, err := buildCrocOptions(false, code, o)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(context.Background())
	c, err := croc.NewCtx(ctx, co)
	if err != nil {
		cancel()
		return nil, err
	}
	s := &session{client: c, ctxCancel: cancel, delegate: d, sender: false, done: make(chan struct{}), pollDone: make(chan struct{})}

	// Accept/decline prompt bridge: croc reads the answer via
	// utils.GetInputContext, which reads a bufio.Reader created once, at package
	// init, wrapping the real fd 0 -- reassigning the os.Stdin *variable*
	// later has no effect on that already-built reader. So beyond swapping
	// the variable (for anything that does read it fresh), dup2 the pipe's
	// read end onto fd 0 itself so the cached reader also pulls from our
	// pipe. With AutoAccept the accept prompt is skipped, so only answers for
	// the un-gated prompts are queued before the pipe closes; any prompt past
	// them hits EOF instead of hanging.
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
		s.answerUngatedPrompts()
	}

	// Text transfers stream to os.Stdout; capture it.
	cr, cw, err := os.Pipe()
	if err != nil {
		os.Stdin = origStdin
		_ = syscall.Dup2(savedStdinFd, syscall.Stdin)
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
		defer func() { recover() }() //nolint:errcheck // gobind: a goroutine panic kills the host app
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
		_ = syscall.Dup2(savedStdinFd, syscall.Stdin)
		syscall.Close(savedStdinFd)
		pr.Close()
	}

	*committed = true
	go s.run(func() error { return c.Receive() }, origWD, func() { activeMu.Unlock() })
	go s.poll()
	return s, nil
}

// run executes the transfer, then restores globals and reports the outcome.
//
// The three terminal delegate calls are recover-protected like xfer() itself:
// gomobile turns an ObjC exception raised inside a delegate callback into a Go
// panic, and OnError/OnText/OnDone fire on every transfer, so an unrecovered
// panic there is a routine App Store crash, not an edge case. The cleanup
// between xfer() and them is plain stdlib and deliberately left unguarded.
func (s *session) run(xfer func() error, origWD string, release func()) {
	var err error
	func() {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("croc panic: %v\n%s", r, debug.Stack())
			}
		}()
		err = xfer()
	}()
	close(s.done)
	s.closePrompt()
	if s.restoreIO != nil {
		drainPromptInput()
	}
	text := s.finishStdoutCapture()
	if s.tempPath != "" {
		os.Remove(s.tempPath)
	}
	removeTempFiles()
	restoreWD(origWD)

	// poll() only notices s.done on its next 100ms tick; wait for it to
	// actually exit so a straggling OnProgress can't interleave with the
	// terminal event below. Bounded so a wedged poll goroutine can never
	// hang the transfer's completion.
	select {
	case <-s.pollDone:
	case <-time.After(2 * time.Second):
	}

	// release must outlive the terminal delegate calls: it unblocks
	// StartSend/StartReceive for the next transfer, and if it ran before
	// OnError/OnText/OnDone, transfer N+1 could start while transfer N is
	// still delivering its final event. Deferred first so it runs last;
	// the recover below is deferred second so it runs first, guaranteeing
	// release still fires even if a delegate call panics.
	defer release()
	defer func() {
		if r := recover(); r != nil {
			reportPanic(s, r)
		}
	}()
	if err != nil {
		s.delegate.OnError(errorJSON(err))
		return
	}
	if text != "" {
		s.delegate.OnText(text)
	}
	s.delegate.OnDone(s.summaryJSON())
}

// removeTempFiles deletes the zip croc builds for a zipped-folder send. croc
// deletes it itself only after a successful send; on a failure, a cancel or a
// setup error it is left to the caller (the CLI sweeps it on exit). A failed
// delete must not fail the transfer, so it is logged.
func removeTempFiles() {
	if err := utils.RemoveMarkedFiles(); err != nil {
		log.Printf("crocmobile: remove temp files: %v", err)
	}
}

// reportPanic converts a recovered panic into an OnError delegate call,
// guarded against the delegate itself panicking again on the way out.
func reportPanic(s *session, r any) {
	defer func() { recover() }() //nolint:errcheck // OnError may panic again; never let that escape
	s.delegate.OnError(failureJSON(codeOther, fmt.Sprintf("croc panic: %v\n%s", r, debug.Stack())))
}

// restoreWD puts back the cwd a transfer changed. A failure cannot be undone
// here, but it leaves the next transfer resolving relative paths elsewhere, so
// it is logged rather than dropped.
func restoreWD(dir string) {
	if err := os.Chdir(dir); err != nil {
		log.Printf("crocmobile: restore working directory: %v", err)
	}
}

// cancel also closes the prompt pipe. croc's GetInputContext returns as soon
// as the context is cancelled, so a pending accept prompt unwinds Receive()
// with context.Canceled, but the goroutine it started to read fd 0 stays
// blocked until the pipe closes. Closing it here ends that read before run()
// restores fd 0, so it cannot linger into the next transfer. closePrompt is
// idempotent and nil-guarded (a no-op for senders, or once respond() has run),
// so it's always safe to call.
func (s *session) cancel() {
	s.ctxCancel()
	s.closePrompt()
}

func (s *session) respond(accept bool, policy filePolicy) {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW == nil {
		return
	}
	if accept {
		// One "y\n" per file for the sender's Ask path (croc prompts once per
		// file, see promptAnswers doc); receiver accept/decline only ever
		// needs the one. Writes can block once the answers outgrow the pipe
		// buffer, which is why Transfer.Respond runs this off the caller's
		// goroutine.
		n := s.promptAnswers
		if n < 1 {
			n = 1
		}
		answers := strings.Repeat("y\n", n)
		if !s.sender {
			// Before the write: croc reads Rename and Overwrite only once the
			// accept prompt has its answer (croc.go updateIfRecipientHasFileInfo).
			if s.client != nil {
				policy.apply(&s.client.Options)
			}
			answers += policy.promptAnswers()
		}
		_, _ = s.promptW.WriteString(answers)
	} else {
		_, _ = s.promptW.WriteString("n\n")
	}
	// Close so any later un-gated prompt hits EOF instead of hanging (see the
	// AutoAccept note in startReceiveSession).
	s.promptW.Close()
	s.promptW = nil
}

// answerUngatedPrompts queues answers for an AutoAccept receive, which has no
// accept prompt, and closes the pipe. Always Keep Both's "n", whatever the
// policy: croc still forces the accept prompt when the remote sender ran
// --ask, that prompt reads the first queued line, and "y" would accept a
// transfer the sender wanted confirmed by hand. So under AutoAccept, Replace
// overwrites files through croc's Overwrite but keeps existing zip members.
func (s *session) answerUngatedPrompts() {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW == nil {
		return
	}
	_, _ = s.promptW.WriteString(keepBoth.promptAnswers())
	s.promptW.Close()
	s.promptW = nil
}

// drainPromptInput reads croc's stdin reader to EOF once the prompt pipe is
// closed and before fd 0 is restored. utils.GetInputContext reads through one
// process-wide bufio.Reader, which buffers answers croc never asked for (the
// policy batch, extra sender-Ask lines); left there, the next transfer's
// accept prompt would read them instead of the user's answer. A croc read
// left blocked by a cancel sees EOF from the same close, so it cannot hold
// data back. Bounded by a timeout in case the pipe is somehow still open.
func drainPromptInput() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	for {
		if _, err := utils.GetInputContext(ctx, ""); err != nil {
			if errors.Is(err, context.DeadlineExceeded) {
				log.Printf("crocmobile: drain prompt input: %v", err)
			}
			return
		}
	}
}

func (s *session) closePrompt() {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW != nil {
		s.promptW.Close()
		s.promptW = nil
	}
}

// installPromptPipe dup2s a pipe's read end onto fd 0 so croc's cached
// stdin reader (built once at package init) pulls from us instead of the
// real stdin. Same trick as the receive path (see the long comment in
// startReceiveSession); used on the send path only when Ask is set, since
// croc's sender-side "Send to machine X? (Y/n)" prompt (croc.go, gated
// only on Options.Ask, not NoPrompt) otherwise blocks forever.
// Returns the restore func; caller stores it in s.restoreIO.
func (s *session) installPromptPipe() (func(), error) {
	pr, pw, err := os.Pipe()
	if err != nil {
		return nil, err
	}
	savedStdinFd, err := syscall.Dup(syscall.Stdin)
	if err != nil {
		pr.Close()
		pw.Close()
		return nil, err
	}
	if err := syscall.Dup2(int(pr.Fd()), syscall.Stdin); err != nil {
		syscall.Close(savedStdinFd)
		pr.Close()
		pw.Close()
		return nil, err
	}
	origStdin := os.Stdin
	os.Stdin = pr
	s.promptW = pw
	return func() {
		os.Stdin = origStdin
		_ = syscall.Dup2(savedStdinFd, syscall.Stdin)
		syscall.Close(savedStdinFd)
		pr.Close()
	}, nil
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
	defer close(s.pollDone)      // run() waits on this; must close even if the loop below panics
	defer func() { recover() }() //nolint:errcheck // backstop: anything escaping the per-tick recover must not kill the goroutine
	t := time.NewTicker(100 * time.Millisecond)
	defer t.Stop()
	connected, listSent := false, false
	// Last payload actually emitted. Its zero value has an empty Step, which no
	// real snapshot ever carries, so the first tick always emits.
	var last progressState
	for {
		select {
		case <-s.done:
			return
		case <-t.C:
		}
		func() {
			// Per-tick recover: one bad delegate call must not silently
			// freeze progress for the rest of the transfer.
			defer func() { recover() }() //nolint:errcheck // racy field reads / delegate panics must never crash the app
			c := s.client
			if !connected && c.Step1ChannelSecured {
				connected = true
				s.delegate.OnConnected()
			}
			if !s.sender && !listSent && len(c.FilesToTransfer) > 0 {
				listSent = true
				s.delegate.OnFileList(s.fileListJSON())
			}
			// Skip unchanged ticks: idle stretches (unanswered accept prompt,
			// a stalled connection) would otherwise marshal and cross the
			// gobind boundary 10x a second with identical numbers. Diff the
			// scalars, not the JSON, or the marshal being avoided still runs.
			// No consumer treats a tick as a heartbeat.
			p := s.progressSnapshot(connected)
			if p == last {
				return
			}
			last = p
			b, _ := json.Marshal(p)
			s.delegate.OnProgress(string(b))
		}()
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

// progressState is the whole progress payload as comparable scalars, so poll
// can diff two ticks without marshalling either of them.
type progressState struct {
	CurrentFile   int    `json:"currentFile"`
	TotalFiles    int    `json:"totalFiles"`
	FileName      string `json:"fileName"`
	FileSent      int64  `json:"fileSent"`
	FileSize      int64  `json:"fileSize"`
	BytesFinished int64  `json:"bytesFinished"`
	TotalSize     int64  `json:"totalSize"`
	Step          string `json:"step"`
}

func (s *session) progressSnapshot(connected bool) progressState {
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
	return progressState{
		CurrentFile: cur, TotalFiles: len(c.FilesToTransfer), FileName: fileName,
		FileSent: sent, FileSize: fileSize, BytesFinished: bytesFinished,
		TotalSize: totalSize, Step: step,
	}
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
