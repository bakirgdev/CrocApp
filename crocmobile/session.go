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

	sender  bool
	promptW *os.File // write end of the stdin pipe; nil once closed
	promptM sync.Mutex

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

func startSession(sender bool, code string, paths []string, text string, o *Options, d Delegate) (*session, error) {
	if !activeMu.TryLock() {
		return nil, errors.New("another transfer is active")
	}
	release := func() { activeMu.Unlock() }

	origWD, _ := os.Getwd()

	if sender {
		secret := o.Code
		if secret == "" {
			secret = utils.GetRandomName()
		}
		if len(secret) < 6 {
			release()
			return nil, errors.New("code is too short (must be at least 6 characters)")
		}
		if o.WorkDir != "" {
			if err := os.Chdir(o.WorkDir); err != nil {
				release()
				return nil, fmt.Errorf("workdir: %w", err)
			}
		}
		if text != "" {
			f, err := os.CreateTemp(".", "croc-stdin-*")
			if err != nil {
				release()
				return nil, err
			}
			if _, err := f.WriteString(text); err != nil {
				f.Close()
				release()
				return nil, err
			}
			f.Close()
			paths = []string{f.Name()}
		}
		filesInfo, emptyFolders, totalFolders, err := croc.GetFilesInfoWithExactExclusions(
			paths, o.ZipFolder, o.GitIgnore, splitNonEmpty(o.Exclude, "\n"), nil)
		if err != nil {
			os.Chdir(origWD)
			release()
			return nil, err
		}
		co := buildCrocOptions(true, secret, o)
		co.SendingText = text != ""
		ctx, cancel := context.WithCancel(context.Background())
		c, err := croc.NewCtx(ctx, co)
		if err != nil {
			cancel()
			os.Chdir(origWD)
			release()
			return nil, err
		}
		s := &session{client: c, ctxCancel: cancel, delegate: d, sender: true, done: make(chan struct{})}
		d.OnCodeReady(secret)
		go s.run(func() error { return c.Send(filesInfo, emptyFolders, totalFolders) }, origWD, release)
		go s.poll()
		return s, nil
	}
	return nil, errors.New("receive not implemented") // Task 3 replaces this line with startReceiveSession
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

func (s *session) cancel() { s.ctxCancel() }

func (s *session) respond(accept bool) {
	s.promptM.Lock()
	defer s.promptM.Unlock()
	if s.promptW == nil {
		return
	}
	if accept {
		s.promptW.WriteString("y\n")
	} else {
		s.promptW.WriteString("n\n")
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

func (s *session) finishStdoutCapture() string { return "" } // Task 3

// poll translates Client fields into delegate events at 10 Hz.
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
	cur := c.FilesToTransferCurrentNum
	var fileName string
	var fileSize, totalSize, bytesFinished int64
	for i, f := range c.FilesToTransfer {
		totalSize += f.Size
		if _, ok := c.FilesHasFinished[i]; ok {
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
