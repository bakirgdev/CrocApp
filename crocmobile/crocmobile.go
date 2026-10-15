package crocmobile

import (
	"errors"
	"fmt"
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
	Curve          string
	HashAlgorithm  string
	ThrottleUpload string
	Code           string // custom code phrase (send); empty = auto-generate
	OutDir         string // receive destination (required on receive)
	WorkDir        string // send: writable cwd for temp files (text/zip); required on iOS
	Exclude        string // newline-joined substring patterns
	DisableLocal   bool
	OnlyLocal      bool
	NoCompress     bool
	ZipFolder      bool
	GitIgnore      bool
	Overwrite      bool // receive: replace a colliding file, unless Rename is set
	Rename         bool // receive: keep both, croc names the new file "name (1).ext"; also the default when neither is set
	AutoAccept     bool // maps to croc NoPrompt; default false (product pillar)
	Ask            bool
	NoMultiplexing bool
	Transport      string // send: TransportAuto (also when empty) or TransportRelay; a receive follows the sender

	// Advanced options. Zero values mean croc's defaults.
	BasePort         int    // send: first port of this side's local relay (croc --port)
	Transfers        int    // send: data ports after BasePort (croc --transfers)
	MulticastAddress string // IPv4 group for LAN discovery (croc --multicast)
	PeerIP           string // receive: the sender's ip:port (croc --ip); skips relays, discovery and the public pool
	Socks5Proxy      string // host:port or socks5:// URL (croc --socks5); wins over HTTPProxy; may carry credentials
	HTTPProxy        string // host:port or http(s):// URL (croc --connect); may carry credentials
	InternalDNS      bool   // resolve relay names with croc's built-in resolver (croc --internal-dns)
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
		Curve:            "p256",
		HashAlgorithm:    "xxhash",
		BasePort:         DefaultBasePort,
		Transfers:        DefaultTransfers,
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

// Transports a send can use, as Options.Transport takes them. Auto lets croc
// race its relay against Tailcat for sends of 128 MiB or more; relay never
// starts Tailcat. croc's own "derp" (Tailcat only, no fallback) also passes
// through, for harness probes.
const (
	TransportAuto  = "auto"
	TransportRelay = "relay"
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
// gets the same recover: a panic here must become a reported error, never
// crash the host app.
func (t *Transfer) Cancel() {
	defer func() {
		if r := recover(); r != nil {
			reportPanic(t.s, r)
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
// would strand a following Cancel behind it. session.respond self-serialises on
// promptM, so running it off the caller's goroutine is safe.
func (t *Transfer) Respond(accept bool, policy string) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				reportPanic(t.s, r)
			}
		}()
		t.s.respond(accept, parsePolicy(policy))
	}()
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
