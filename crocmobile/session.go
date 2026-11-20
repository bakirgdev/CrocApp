package crocmobile

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"
	"runtime/debug"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/schollz/croc/v11/src/codephrase"
	"github.com/schollz/croc/v11/src/croc"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/utils"
)

// One transfer at a time: croc needs process-global os.Chdir/os.Stdout.
var activeMu sync.Mutex

// stuckAfter is how long a cancelled session's croc call may take to return
// before the session is reported stuck. croc v11's dials and reads follow its
// context, its reconnect backoff is capped at 5 s and run's own teardown waits
// are bounded at 2 s each, so a healthy cancel returns well inside it. A var so
// tests can shorten it.
var stuckAfter = 15 * time.Second

// stuck is the session whose croc call outlived a cancel by stuckAfter. It
// still holds activeMu, and it keeps it: forcing the lock open would let a new
// session change cwd and stdout under a croc that is still running. So
// every start fails with codeEngineStuck until that session returns, if ever.
var stuck struct {
	sync.Mutex
	s *session
}

func lockTransfer() error {
	if activeMu.TryLock() {
		return nil
	}
	stuck.Lock()
	wedged := stuck.s != nil
	stuck.Unlock()
	if wedged {
		return &codedError{code: codeEngineStuck, err: errors.New("a cancelled transfer never returned")}
	}
	return &codedError{code: codeTransferActive, err: errors.New("another transfer is active")}
}

// pendingStart holds the context cancel of a start that has not returned yet.
// startSession sets it only while it holds activeMu, so there is at most one.
var pendingStart struct {
	sync.Mutex
	start *startCancel
}

type startCancel struct{ cancel context.CancelFunc }

// beginPendingStart makes cancel reachable by CancelStart until the returned
// func runs. That func clears only its own entry: by the time a start returns,
// its transfer may have ended and the next start may have registered.
func beginPendingStart(cancel context.CancelFunc) (end func()) {
	start := &startCancel{cancel: cancel}
	pendingStart.Lock()
	pendingStart.start = start
	pendingStart.Unlock()
	return func() {
		pendingStart.Lock()
		if pendingStart.start == start {
			pendingStart.start = nil
		}
		pendingStart.Unlock()
	}
}

func cancelPendingStart() {
	pendingStart.Lock()
	defer pendingStart.Unlock()
	if pendingStart.start != nil {
		pendingStart.start.cancel()
	}
}

type session struct {
	client    *croc.Client
	ctxCancel context.CancelFunc
	delegate  Delegate

	sender   bool
	tempPath string // absolute path of the text-send temp file, if any; removed in run()

	// answered is closed by respond once answer holds the user's decision. It
	// can come before croc asks: the app shows the send confirm on connect.
	answered   chan struct{}
	answerOnce sync.Once
	answer     struct {
		accept bool
		policy filePolicy
	}
	// offer is the question the user said yes to. croc asks again after each
	// reconnect, and only the same offer gets the same answer (#226).
	offer atomic.Pointer[croc.Question]

	restoreIO func() // receive: restore os.Stdout and end its capture

	stdoutBuf []byte // captured os.Stdout (text receive)
	stdoutM   sync.Mutex

	done     chan struct{}
	pollDone chan struct{} // closed when poll() returns; run() waits on it before the terminal delegate calls

	storeAnswer chan storeReply // stored receive only: carries Respond to the goroutine waiting at the preview

	terminal  atomic.Bool // the terminal OnDone or OnError was claimed, by run (or runStore) or by the cancel watchdog
	watchOnce sync.Once   // starts the cancel watchdog once
}

func buildCrocOptions(sender bool, secret string, o *Options) (croc.Options, error) {
	route, err := resolveRelay(secret, o)
	if err != nil {
		return croc.Options{}, err
	}
	password := o.RelayPassword
	if password == "" {
		password = models.DEFAULT_PASSPHRASE
	}
	// Transport stays empty, croc's auto. The engine is built with the
	// croc_no_tailcat tag (scripts/build-xcframework.sh), under which auto
	// means the relay and the LAN, never Tailcat.
	co := croc.Options{
		IsSender:         sender,
		SharedSecret:     secret,
		RelayAddress:     route.v4,
		RelayAddress6:    route.v6,
		PublicRelay:      route.public,
		RelayPassword:    password,
		RelayPorts:       relayPorts(),
		Curve:            crocCurve,
		ThrottleUpload:   strings.TrimSpace(o.ThrottleUpload),
		DisableLocal:     o.DisableLocal,
		OnlyLocal:        o.OnlyLocal,
		NoCompress:       o.NoCompress,
		ZipFolder:        o.ZipFolder,
		GitIgnore:        o.GitIgnore,
		Exclude:          splitNonEmpty(o.Exclude, "\n"),
		NoPrompt:         sender || o.AutoAccept, // sender-side prompts only exist for Ask
		Ask:              o.Ask,
		IgnoreStdin:      true,
		DisableClipboard: true,
		Quiet:            false, // Quiet=true nukes process stderr globally
		IP:               strings.TrimSpace(o.PeerIP),
		MulticastAddress: crocMulticastAddress,
	}
	optionsPolicy(o).apply(&co)
	return co, nil
}

// filePolicy decides what a receive does with a file whose name already
// exists. croc itself has a third state, Rename and Overwrite both false, in
// which it asks per file; it is never passed to croc. The same policy answers
// croc's overwrite questions for zip members and non-empty folders (prompt).
type filePolicy int

const (
	keepBoth filePolicy = iota
	replace
)

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

// maxReportedBytes caps every size and byte sum the delegate sees (1 PiB). A
// file list's sizes are the sender's word, and unchecked sums of them overflow
// int64 here and trap in the app's Int64 arithmetic.
const maxReportedBytes = 1 << 50

func addReported(total, size int64) int64 {
	return min(total+min(max(size, 0), maxReportedBytes), maxReportedBytes)
}

// sendFilesInfo hands croc the picked paths as literal names. croc expands any
// path holding '*' with filepath.Glob, so a picked file named "*.pdf" would
// also send every PDF beside it; escaping the pattern makes it match only
// itself.
func sendFilesInfo(ctx context.Context, paths []string, o *Options) ([]croc.FileInfo, []croc.FileInfo, int, error) {
	literal := make([]string, len(paths))
	for i, p := range paths {
		if strings.Contains(p, "*") {
			p = globEscaper.Replace(p)
		}
		literal[i] = p
	}
	exclude := splitNonEmpty(strings.ToLower(o.Exclude), "\n")
	files, empty, folders, err := croc.GetFilesInfoContext(ctx, literal, o.ZipFolder, o.GitIgnore, exclude)
	if err != nil || len(exclude) == 0 {
		return files, empty, folders, err
	}
	// croc applies substring exclusions only inside a zip; for every other
	// send its CLI filters the list afterwards (cli.go), which a library
	// caller has to repeat.
	files, empty = withoutExcluded(files, exclude), withoutExcluded(empty, exclude)
	if len(files) == 0 && len(empty) == 0 {
		return nil, nil, 0, &codedError{codeNothingToSend, errors.New("every file in the picked folders matches an exclude pattern")}
	}
	// As croc's walk counts them: every folder but the root.
	remote := map[string]bool{}
	for _, f := range append(files, empty...) {
		if f.FolderRemote != rootFolder {
			remote[f.FolderRemote] = true
		}
	}
	return files, empty, len(remote), nil
}

// rootFolder is croc's FolderRemote for an item the user picked itself.
const rootFolder = "./"

// withoutExcluded drops what a pattern matches inside a picked folder. An item
// the user picked itself stays (so does croc's zip of a picked folder, which
// was filtered when it was written): the patterns are for folder contents.
func withoutExcluded(infos []croc.FileInfo, exclude []string) []croc.FileInfo {
	var kept []croc.FileInfo
	for _, f := range infos {
		name := path.Join(strings.ToLower(f.FolderRemote), strings.ToLower(f.Name))
		if f.FolderRemote == rootFolder || !slices.ContainsFunc(exclude, func(e string) bool { return strings.Contains(name, e) }) {
			kept = append(kept, f)
		}
	}
	return kept
}

var globEscaper = strings.NewReplacer(`\`, `\\`, `*`, `\*`, `?`, `\?`, `[`, `\[`)

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
// from croc.GetFilesInfoWithExactExclusionsContext/croc.NewCtx, and (because
// `committed` is only set true right before the `go s.run(...)` call, after
// d.OnCodeReady returns) any panic raised by the delegate's OnCodeReady
// itself. This is what guarantees the lock, cwd, temp file and croc's network
// globals (setNetworkGlobals) are never leaked, even across a panic. The panic itself is left to propagate to
// StartSend/StartReceive's own recover, which converts it into a returned
// error.
func startSession(sender bool, code string, paths []string, text string, o *Options, d Delegate) (*session, error) {
	if err := validateNetworkOptions(o); err != nil {
		return nil, err
	}
	if err := lockTransfer(); err != nil {
		return nil, err
	}
	origWD, err := os.Getwd()
	if err != nil {
		activeMu.Unlock()
		return nil, fmt.Errorf("working directory: %w", err)
	}
	restoreNetwork := setNetworkGlobals(o)
	release := func() {
		restoreNetwork()
		activeMu.Unlock()
	}
	// The session's context exists before the slow setup (the public relay
	// probe), so CancelStart can stop a start that has not returned its
	// Transfer yet. The same context then carries the transfer.
	ctx, cancel := context.WithCancel(context.Background())
	defer beginPendingStart(cancel)()
	var tempPath string
	committed := false
	defer func() {
		if !committed {
			cancel()
			removeTempFiles()
			if tempPath != "" {
				os.Remove(tempPath)
			}
			restoreWD(origWD)
			release()
		}
	}()

	if sender {
		secret := o.Code
		generatedPublic := secret == "" && usesPublicRelay(o)
		if secret == "" {
			var err error
			if generatedPublic {
				secret, err = generatePublicCode(ctx, relayProbe)
			} else {
				secret, err = codephrase.Generate()
			}
			if err != nil {
				return nil, fmt.Errorf("could not generate code phrase: %w", err)
			}
		}
		if len(secret) < MinCodeLength {
			return nil, fmt.Errorf("code is too short (must be at least %d characters)", MinCodeLength)
		}
		if o.WorkDir != "" {
			if err := os.Chdir(o.WorkDir); err != nil {
				return nil, fmt.Errorf("workdir: %w", err)
			}
		}
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
		listing := o
		if text != "" {
			// Exclude patterns are for picked files; one must never drop the text's temp file.
			noExclude := *o
			noExclude.Exclude = ""
			listing = &noExclude
		}
		filesInfo, emptyFolders, totalFolders, err := sendFilesInfo(ctx, paths, listing)
		if err != nil {
			return nil, err
		}
		co, err := buildCrocOptions(true, secret, o)
		if err != nil {
			return nil, err
		}
		co.SendingText = text != ""
		c, err := croc.NewCtx(ctx, co)
		if err != nil {
			return nil, err
		}
		s := newSession(c, cancel, d, true)
		s.tempPath = tempPath
		// A CancelStart during setup ends the start here, before the code shows.
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		// OnCodeReady runs before we commit: if the delegate panics here, the
		// cleanup defer above must still be armed to release the lock, cwd,
		// and temp file, rather than leaking them because we'd already
		// (wrongly) considered the async run started.
		d.OnCodeReady(secret)
		committed = true
		go s.run(func() error {
			err := c.Send(filesInfo, emptyFolders, totalFolders)
			if generatedPublic && errors.Is(err, croc.ErrRelayConnection) {
				forgetPublicRelay()
			}
			return err
		}, origWD, release)
		go s.poll()
		return s, nil
	}
	return startReceiveSession(ctx, cancel, code, o, d, origWD, release, &committed)
}

// startReceiveSession is startSession's receive-side counterpart, called as a
// tail call from within startSession's own frame: the `committed` guard defer
// declared there is still armed for every error path below, so on failure we
// only need to unwind whatever this function itself set up (the os.Stdout
// capture); the croc ctx cancel, cwd restore and release (network
// globals, then the activeMu unlock) are handled by that defer once we return. Only
// right before the async run actually starts do we flip *committed to true,
// handing ownership of cwd and the lock to s.run/release.
func startReceiveSession(ctx context.Context, cancel context.CancelFunc, code string, o *Options, d Delegate, origWD string, release func(), committed *bool) (*session, error) {
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
	c, err := croc.NewCtx(ctx, co)
	if err != nil {
		return nil, err
	}
	s := newSession(c, cancel, d, false)

	// Text transfers stream to os.Stdout; capture it.
	cr, cw, err := os.Pipe()
	if err != nil {
		return nil, err
	}
	origStdout := os.Stdout
	os.Stdout = cw
	captureDone := make(chan struct{})
	go func() {
		defer close(captureDone)
		defer ignorePanic() // gobind: a goroutine panic kills the host app
		buf := make([]byte, 32*1024)
		for {
			n, err := cr.Read(buf)
			if n > 0 {
				s.stdoutM.Lock()
				// croc refuses text over 1 MiB before it streams (textTooLong), so
				// this cap only bounds memory if that check ever goes away.
				if len(s.stdoutBuf) < 10*1024*1024 {
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
		os.Stdout = origStdout
		cw.Close()
		<-captureDone
		cr.Close()
	}

	*committed = true
	go s.run(func() error { return c.Receive() }, origWD, release)
	go s.poll()
	return s, nil
}

// The three terminal delegate calls are recover-protected like xfer() itself:
// gomobile turns an ObjC exception raised inside a delegate callback into a Go
// panic, and OnError/OnText/OnDone fire on every transfer, so an unrecovered
// panic there is a routine App Store crash, not an edge case. The cleanup
// between xfer() and them is plain stdlib and deliberately left unguarded.
func (s *session) run(xfer func() error, origWD string, release func()) {
	var err error
	func() {
		defer recoverInto(&err)
		err = xfer()
	}()
	if err != nil && s.offer.Load() != nil && classify(err) == codeRefused {
		// The drop ended the transfer, not the user: croc re-asked with an
		// offer other than the one they accepted. Report what they can retry.
		err = &codedError{code: codeConnectionLost, err: fmt.Errorf("reconnect after accept changed the offer: %w", err)}
	}
	close(s.done)
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

	// Released before the terminal delegate calls, once every process global
	// is restored: a consumer that starts the next transfer as soon as it sees
	// OnDone or OnError must find the engine free. Each transfer has its own
	// delegate, so N's last event cannot reach N+1.
	unmarkStuck(s)
	release()
	if !s.terminal.CompareAndSwap(false, true) {
		return // the cancel watchdog already reported this session stuck
	}
	defer reportRecovered(s)
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

// The recover helpers below are deferred directly (defer ignorePanic()):
// recover only works in the deferred function itself.

// ignorePanic swallows a panic where nothing can report it: a goroutine whose
// panic would kill the host app, or a delegate call made while already
// reporting.
func ignorePanic() { _ = recover() }

func panicError(r any) error {
	return fmt.Errorf("croc panic: %v\n%s", r, debug.Stack())
}

func recoverInto(err *error) {
	if r := recover(); r != nil {
		*err = panicError(r)
	}
}

// recoverStart stores a panic in *err as a start failure payload, so an
// exported start function returns an error instead of crashing the host app.
// Its other results keep their zero values: none is assigned before the
// function's last statement.
func recoverStart(err *error) {
	if r := recover(); r != nil {
		*err = startError(panicError(r))
	}
}

// logRecovered records a panic where no terminal event may be sent (Cancel and
// Respond run while the transfer's own run goroutine still owns that event).
func logRecovered(where string) {
	if r := recover(); r != nil {
		log.Printf("crocmobile: panic in %s: %v\n%s", where, r, debug.Stack())
	}
}

func reportRecovered(s *session) {
	if r := recover(); r != nil {
		reportPanic(s, r)
	}
}

// reportPanic sends r as OnError, guarded against the delegate itself
// panicking again on the way out.
func reportPanic(s *session, r any) {
	defer ignorePanic()
	s.delegate.OnError(failureJSON(codeOther, panicError(r).Error()))
}

// restoreWD puts back the cwd a transfer changed. A failure cannot be undone
// here, but it leaves the next transfer resolving relative paths elsewhere, so
// it is logged rather than dropped.
func restoreWD(dir string) {
	if err := os.Chdir(dir); err != nil {
		log.Printf("crocmobile: restore working directory: %v", err)
	}
}

// cancel also ends a question prompt is waiting on: it waits on the same
// context.
func (s *session) cancel() {
	s.ctxCancel()
	s.watchOnce.Do(func() { go s.watchCancel(stuckAfter) })
}

// watchCancel reports the session stuck when croc has not returned within
// after (stuckAfter) of a cancel. The delegate gets codeEngineStuck as its
// terminal event, so the app can leave its cancelling state, and later starts
// fail fast with the same code (lockTransfer). The lock is not forced open
// (see stuck). If croc returns after all, run clears the mark and frees the
// engine.
func (s *session) watchCancel(after time.Duration) {
	defer ignorePanic() // gobind: a goroutine panic kills the host app
	t := time.NewTimer(after)
	defer t.Stop()
	select {
	case <-s.done:
		return
	case <-t.C:
	}
	stuck.Lock()
	select {
	case <-s.done: // croc returned as the timer fired
		stuck.Unlock()
		return
	default:
	}
	stuck.s = s
	stuck.Unlock()
	msg := fmt.Sprintf("transfer did not return %v after cancel", after)
	log.Printf("crocmobile: %s", msg)
	if s.terminal.CompareAndSwap(false, true) {
		s.delegate.OnError(failureJSON(codeEngineStuck, msg))
	}
}

// unmarkStuck clears the stuck mark of a session whose croc call returned
// after all. Called after close(s.done), so watchCancel, which checks s.done
// under the same lock, can never mark it afterwards.
func unmarkStuck(s *session) {
	stuck.Lock()
	if stuck.s == s {
		stuck.s = nil
	}
	stuck.Unlock()
}

func newSession(c *croc.Client, cancel context.CancelFunc, d Delegate, sender bool) *session {
	s := &session{client: c, ctxCancel: cancel, delegate: d, sender: sender, answered: make(chan struct{}), done: make(chan struct{}), pollDone: make(chan struct{})}
	c.Options.Prompt = s.prompt
	return s
}

// respond records the user's first answer; croc may not have asked yet. A
// second answer (a double tap) is dropped.
func (s *session) respond(accept bool, policy filePolicy) {
	if s.storeAnswer != nil {
		s.answerStore(accept, policy)
		return
	}
	s.answerOnce.Do(func() {
		s.answer.accept, s.answer.policy = accept, policy
		close(s.answered)
	})
}

// prompt answers croc's yes/no questions (Options.Prompt) on croc's goroutine.
// With it set, croc reads no stdin.
func (s *session) prompt(ctx context.Context, q croc.Question) (bool, error) {
	switch q.Kind {
	case croc.QuestionAccept, croc.QuestionSend:
		if !q.Required {
			return true, nil // an accept under AutoAccept
		}
		if s.client.Options.NoPrompt && !s.sender {
			// AutoAccept, but the sender ran --ask, which needs a person, and
			// the app shows nobody the offer under AutoAccept.
			return false, nil
		}
		if accepted := s.offer.Load(); accepted != nil {
			return sameOffer(*accepted, q, s.client.Options.Rename), nil
		}
		select {
		case <-s.answered:
		case <-ctx.Done():
			return false, ctx.Err()
		}
		if !s.answer.accept {
			return false, nil
		}
		if q.Kind == croc.QuestionAccept {
			// croc reads Rename and Overwrite only once this question has its
			// answer (croc.go updateIfRecipientHasFileInfo).
			s.answer.policy.apply(&s.client.Options)
		}
		s.offer.Store(&q)
		return true, nil
	case croc.QuestionOverwrite:
		// A zip member, a non-empty folder an empty one replaces, or a file
		// (never asked: Rename or Overwrite is always set).
		return s.client.Options.Overwrite, nil
	}
	return false, nil
}

// sameOffer reports whether croc re-asked after a reconnect with the offer the
// user accepted in a. A hash counts only when both carry one: the sender may
// still have been hashing at the first ask. Only Keep Both (renamed) renames,
// so under Replace a "(n)" name is a different file, which it would overwrite.
func sameOffer(a, b croc.Question, renamed bool) bool {
	return a.Kind == b.Kind && a.Name == b.Name && a.EmptyFolders == b.EmptyFolders &&
		slices.EqualFunc(a.Files, b.Files, func(x, y croc.FileInfo) bool {
			return x.FolderRemote == y.FolderRemote &&
				(x.Name == y.Name || renamed && keptName(x.Name, y.Name)) &&
				x.Size == y.Size && x.Symlink == y.Symlink && x.TempFile == y.TempFile &&
				(len(x.Hash) == 0 || len(y.Hash) == 0 || bytes.Equal(x.Hash, y.Hash))
		})
}

// keptName reports whether name is offered, or the "offered (n).ext" Keep Both
// gave it: croc re-offers a file it finished under that name
// (receive_preflight.go unusedReceiveName, bundle.go restoreBundleDestinations).
func keptName(offered, name string) bool {
	if name == offered {
		return true
	}
	ext := path.Ext(offered)
	n, ok := strings.CutPrefix(name, strings.TrimSuffix(offered, ext)+" (")
	if !ok {
		return false
	}
	n, ok = strings.CutSuffix(n, ")"+ext)
	i, err := strconv.Atoi(n)
	return ok && err == nil && i > 0 && strconv.Itoa(i) == n // croc writes no "+1" or "01"
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
	defer close(s.pollDone) // run() waits on this; must close even if the loop below panics
	defer ignorePanic()     // backstop: anything escaping the per-tick recover must not kill the goroutine
	t := time.NewTicker(100 * time.Millisecond)
	defer t.Stop()
	connected, listSent := false, false
	// Last payload actually emitted. Its zero value has an empty Step, which no
	// real snapshot ever carries, so the first tick always emits.
	var last progressState
	for {
		select {
		case <-s.done:
			// A transfer that ends inside one tick (a small file over a fast
			// link, auto-accepted) would otherwise never report its list.
			if !s.sender && !listSent && len(s.client.FilesToTransfer) > 0 {
				func() {
					defer ignorePanic() // a delegate panic must not skip close(pollDone)
					s.delegate.OnFileList(s.fileListJSON())
				}()
			}
			return
		case <-t.C:
		}
		func() {
			// Per-tick recover: one bad delegate call must not silently
			// freeze progress for the rest of the transfer.
			defer ignorePanic() // racy field reads / delegate panics must never crash the app
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

// fileListPayload and summaryPayload are the fileList and done events' JSON,
// shared by CLI and stored sessions. Fields stay in key order: the interop
// harness greps the exact bytes.
type fileListPayload struct {
	EmptyFolders int         `json:"emptyFolders"`
	Files        []fileEntry `json:"files"`
	TotalSize    int64       `json:"totalSize"`
}

func (p fileListPayload) json() string {
	b, _ := json.Marshal(p)
	return string(b)
}

type summaryPayload struct {
	Files     int   `json:"files"`
	Success   bool  `json:"success"`
	TotalSize int64 `json:"totalSize"`
}

func (p summaryPayload) json() string {
	b, _ := json.Marshal(p)
	return string(b)
}

func (s *session) fileListJSON() string {
	c := s.client
	// Not nil: an empty list must marshal as [], which DelegateBridge expects.
	files := make([]fileEntry, 0, len(c.FilesToTransfer))
	var total int64
	for _, f := range c.FilesToTransfer {
		name := filepath.Join(f.FolderRemote, f.Name)
		files = append(files, fileEntry{Name: name, Size: addReported(0, f.Size)})
		total = addReported(total, f.Size)
	}
	return fileListPayload{len(c.EmptyFoldersToTransfer), files, total}.json()
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
	sent := addReported(0, c.TotalSent)
	// croc moves a run of small files as one bundle without moving
	// FilesToTransferCurrentNum, and adds the bundle's bytes to the TotalSent
	// left by the file before it (crocmobile-bridge.md, "Small-file bundles").
	// The bundle holds the files after that one, in order, so walk sent onto them.
	for cur >= 0 && cur+1 < len(c.FilesToTransfer) {
		size := addReported(0, c.FilesToTransfer[cur].Size)
		if sent <= size {
			break
		}
		sent -= size
		cur++
	}
	var fileName string
	var fileSize, totalSize, bytesFinished int64
	// Sum sizes of files strictly before the current one instead of indexing
	// c.FilesHasFinished: that map is written unguarded by croc's own
	// goroutines, and a concurrent read here races it -- a fatal, unrecoverable
	// runtime throw, not a panic recover() can catch.
	for i, f := range c.FilesToTransfer {
		totalSize = addReported(totalSize, f.Size)
		if i < cur {
			bytesFinished = addReported(bytesFinished, f.Size)
		}
	}
	if cur >= 0 && cur < len(c.FilesToTransfer) {
		f := c.FilesToTransfer[cur]
		fileName = f.Name
		fileSize = addReported(0, f.Size)
	}
	if c.Step3RecipientRequestFile || c.TotalSent > 0 {
		step = "transferring"
	}
	// sent past the last file is a TotalSent croc has not yet reset for the
	// next single file; the cap keeps bytesFinished+fileSent within totalSize.
	sent = min(sent, fileSize)
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
		total = addReported(total, f.Size)
	}
	return summaryPayload{len(c.FilesToTransfer), c.SuccessfulTransfer, total}.json()
}
