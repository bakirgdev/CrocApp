package crocmobile

import (
	"errors"
	"fmt"
	"log"
	"os"
	"runtime/debug"
	"strings"

	"github.com/schollz/croc/v11/src/models"
)

// Options mirrors croc CLI flags with gobind-safe scalar fields.
//
// Blank relay addresses and password mean croc's defaults. With no custom relay
// and OnlyLocal off, the relay comes from the public pool by code (relay.go).
type Options struct {
	RelayAddress   string
	RelayAddress6  string
	RelayPassword  string
	ThrottleUpload string
	Code           string // custom code phrase (send); empty = auto-generate
	OutDir         string // receive destination (required on receive)
	WorkDir        string // writable temp dir: send's cwd (text/zip), required on iOS and in the Mac sandbox
	Exclude        string // newline-joined substring patterns
	ExcludePaths   string // newline-joined relative paths excluded exactly, inside a sent folder or by a picked file's name (croc --exclude-file)
	DisableLocal   bool
	OnlyLocal      bool
	NoCompress     bool
	ZipFolder      bool
	GitIgnore      bool
	Overwrite      bool // receive: replace a colliding file, unless Rename is set
	Rename         bool // receive: keep both, croc names the new file "name (1).ext"; also the default when neither is set
	AutoAccept     bool // maps to croc NoPrompt; default false (product pillar)
	Ask            bool
	NoMultiplexing bool // one data connection per transfer (croc --no-multi); sender side, so a peer that cannot take several connections still works
	InternalDNS    bool // resolve a direct relay hostname through croc's built-in resolver (croc --internal-dns); proxies keep the hostname for proxy-side DNS

	// Advanced options. Zero values mean croc's defaults.
	MulticastAddress string // IPv4 group for LAN discovery (croc --multicast)
	PeerIP           string // receive: the sender's ip:port (croc --ip); skips relays, discovery and the public pool
	Socks5Proxy      string // host:port or socks5:// URL (croc --socks5); wins over HTTPProxy; may carry credentials
	HTTPProxy        string // host:port or http(s):// URL (croc --connect); may carry credentials
}

// NewOptionsDefault returns croc CLI defaults.
//
// Named with a suffix on purpose. gobind treats any func matching
// "New"+TypeName as a constructor and derives the ObjC selector from the
// remaining suffix, so a bare NewOptions produces `- (nullable instancetype)init`
// on CrocmobileOptions, which clashes with NSObject's nonnull init and warns on
// every Swift build. The suffix makes the selector `initDefault` instead.
func NewOptionsDefault() *Options {
	return &Options{
		RelayAddress:     models.DEFAULT_RELAY,
		RelayAddress6:    models.DEFAULT_RELAY6,
		RelayPassword:    models.DEFAULT_PASSPHRASE,
		MulticastAddress: DefaultMulticastAddress,
	}
}

// Policies for a received file whose name already exists, as Respond takes
// them. Any other value means PolicyKeepBoth: an unknown policy never
// overwrites.
const (
	PolicyKeepBoth = "keepBoth"
	PolicyReplace  = "replace"
)

// minCodeLength is the shortest code phrase StartSend and StartReceive accept,
// counted in bytes. Swift mirrors it as EngineConstraints.minCodeLength.
const minCodeLength = 6

// Delegate receives transfer events. Called on arbitrary Go threads.
type Delegate interface {
	OnCodeReady(code string)
	OnConnected()
	OnFileList(listJSON string)
	OnProgress(progressJSON string)
	OnText(text string)
	OnDone(summaryJSON string)
	OnError(message string)
	// OnStored delivers a finished stored upload's receipt, just before OnDone.
	OnStored(receiptJSON string)
}

// Transfer is a handle to one active transfer.
type Transfer struct {
	s *session
}

// Cancel aborts the transfer; the peer is notified via croc's SendError.
//
// Exported across the gobind boundary like StartSend/StartReceive, so it
// gets the same recover: a panic here must never crash the host app. It is
// only logged (logPanic), because the transfer's terminal event is claimed by
// run, and a second one would break the single-final-event guarantee.
func (t *Transfer) Cancel() {
	defer func() {
		if r := recover(); r != nil {
			logPanic("Cancel", r)
		}
	}()
	t.s.cancel()
}

// Respond answers the receive accept/decline request raised by OnFileList.
// On accept, policy (PolicyKeepBoth or PolicyReplace) replaces the one the
// Options gave. No-op for AutoAccept receivers; senders ignore policy. See
// Cancel for why this recovers.
//
// Asynchronous on purpose: an accept writes one "y\n" per file (promptAnswers),
// and a large enough sender-Ask batch overruns the pipe buffer, blocking the
// write until croc drains it over the network. The caller is CrocKit's
// CrocEngine actor, which runs queued work to completion, so a blocking Respond
// would strand a following Cancel behind it. session.respond writes outside
// promptM, so a Cancel is never held up behind it, and drops an answer that
// arrives while another is being written.
func (t *Transfer) Respond(accept bool, policy string) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logPanic("Respond", r)
			}
		}()
		t.s.respond(accept, parsePolicy(policy))
	}()
}

// SetTempDir points $TMPDIR, where croc v11.6 spools small-file bundles
// (os.CreateTemp("", ...)), at dir for the whole process. The sandboxed Mac app
// inherits a $TMPDIR it cannot write. Call it once at launch, before any
// transfer: os.Setenv also calls libc setenv, which is not safe against a
// getenv on another thread, so it must never run per transfer. A failure is
// logged, like restoreWD, because a bundle then fails with its own error.
func SetTempDir(dir string) {
	if err := os.Setenv("TMPDIR", dir); err != nil {
		log.Printf("crocmobile: set TMPDIR: %v", err)
	}
}

// CancelStart cancels a StartSend or StartReceive that has not returned yet,
// such as a generated-code send still probing the public relays. That start
// then fails with code "cancelled". A no-op when no start is in progress: a
// started transfer is cancelled through its Transfer.
//
// Not tied to a Transfer, because there is none until the start returns. A
// caller with more than one start in flight cannot tell them apart; CrocKit
// runs one start at a time.
func CancelStart() {
	defer func() { recover() }() //nolint:errcheck // gobind: a panic here must never cross into the host app
	cancelPendingStart()
}

// StartSend begins sending. paths is newline-joined absolute paths.
// If text is non-empty a text snippet is sent instead and paths is ignored.
//
// The synchronous body (which invokes croc's file-stat and context setup on
// the caller's goroutine) is wrapped in a recover: a panic here must become
// an error, never crash the host app across the gobind boundary.
func StartSend(pathsJoined string, text string, opts *Options, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	if opts == nil {
		opts = NewOptionsDefault()
	}
	if d == nil {
		return nil, startError(errors.New("delegate required"))
	}
	paths := splitPaths(pathsJoined)
	if text == "" && len(paths) == 0 {
		return nil, startError(errors.New("nothing to send"))
	}
	s, err := startSession(true, "", paths, text, opts, d)
	if err != nil {
		return nil, startError(err)
	}
	return &Transfer{s: s}, nil
}

// StartReceive begins receiving with the given code phrase.
//
// See StartSend for why the synchronous body is wrapped in a recover.
func StartReceive(code string, opts *Options, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	if opts == nil {
		opts = NewOptionsDefault()
	}
	if d == nil {
		return nil, startError(errors.New("delegate required"))
	}
	if len(code) < minCodeLength {
		return nil, startError(fmt.Errorf("code is too short (must be at least %d characters)", minCodeLength))
	}
	s, err := startSession(false, code, nil, "", opts, d)
	if err != nil {
		return nil, startError(err)
	}
	return &Transfer{s: s}, nil
}

// splitPaths splits a "\n"-joined path list without trimming: a file name may
// begin or end with a space.
func splitPaths(joined string) []string {
	var paths []string
	for _, p := range strings.Split(joined, "\n") {
		if p != "" {
			paths = append(paths, p)
		}
	}
	return paths
}
