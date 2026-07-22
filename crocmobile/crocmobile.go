package crocmobile

import (
	"errors"
	"fmt"
	"strings"
)

// Options mirrors croc CLI flags with gobind-safe scalar fields.
type Options struct {
	RelayAddress   string
	RelayAddress6  string
	RelayPassword  string
	RelayPorts     string // comma-joined
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
	Overwrite      bool
	AutoAccept     bool // maps to croc NoPrompt; default false (product pillar)
	Ask            bool
	NoMultiplexing bool
}

// NewOptions returns croc CLI defaults.
func NewOptions() *Options {
	return &Options{
		RelayAddress:  "croc.schollz.com:9009",
		RelayAddress6: "croc6.schollz.com:9009",
		RelayPassword: "pass123",
		RelayPorts:    "9009,9010,9011,9012,9013",
		Curve:         "p256",
		HashAlgorithm: "xxhash",
	}
}

// Delegate receives transfer events. Called on arbitrary Go threads.
type Delegate interface {
	OnCodeReady(code string)
	OnConnected()
	OnFileList(listJSON string)
	OnProgress(progressJSON string)
	OnText(text string)
	OnDone(summaryJSON string)
	OnError(message string)
}

// Transfer is a handle to one active transfer.
type Transfer struct {
	s *session
}

// Cancel aborts the transfer; the peer is notified via croc's SendError.
func (t *Transfer) Cancel() { t.s.cancel() }

// Respond answers the receive accept/decline request raised by OnFileList.
// No-op for senders or AutoAccept receivers.
func (t *Transfer) Respond(accept bool) { t.s.respond(accept) }

// StartSend begins sending. paths is newline-joined absolute paths.
// If text is non-empty a text snippet is sent instead and paths is ignored.
//
// The synchronous body (which invokes croc's file-stat and context setup on
// the caller's goroutine) is wrapped in a recover: a panic here must become
// an error, never crash the host app across the gobind boundary.
func StartSend(pathsJoined string, text string, opts *Options, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, fmt.Errorf("croc panic: %v", r)
		}
	}()
	if opts == nil {
		opts = NewOptions()
	}
	if d == nil {
		return nil, errors.New("delegate required")
	}
	var paths []string
	for _, p := range strings.Split(pathsJoined, "\n") {
		if p = strings.TrimSpace(p); p != "" {
			paths = append(paths, p)
		}
	}
	if text == "" && len(paths) == 0 {
		return nil, errors.New("nothing to send")
	}
	s, err := startSession(true, "", paths, text, opts, d)
	if err != nil {
		return nil, err
	}
	return &Transfer{s: s}, nil
}

// StartReceive begins receiving with the given code phrase.
//
// See StartSend for why the synchronous body is wrapped in a recover.
func StartReceive(code string, opts *Options, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, fmt.Errorf("croc panic: %v", r)
		}
	}()
	if opts == nil {
		opts = NewOptions()
	}
	if d == nil {
		return nil, errors.New("delegate required")
	}
	if len(code) < 6 {
		return nil, errors.New("code is too short (must be at least 6 characters)")
	}
	s, err := startSession(false, code, nil, "", opts, d)
	if err != nil {
		return nil, err
	}
	return &Transfer{s: s}, nil
}
