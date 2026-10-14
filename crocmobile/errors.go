package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"syscall"

	"github.com/schollz/croc/v11/src/croc"
	"github.com/schollz/croc/v11/src/storeclient"
	"github.com/schollz/croc/v11/src/tcp"
)

// Failure codes carried by OnError and by StartSend/StartReceive errors. The
// app maps each code to its own copy and never shows croc's message, so a new
// croc release can change the text without changing what users read. CrocKit's
// EngineFailure.Code mirrors this list; an unknown code decodes as "other".
const (
	codePeerVersion      = "peerVersion"      // the peer runs croc v10 or older
	codeRelayUnreachable = "relayUnreachable" // relay dial, admission or data connection failed
	codeNoPublicRelay    = "noPublicRelay"    // generated code: no public pool relay answered the probe
	codeDeclined         = "declined"         // the peer refused or cancelled ("refusing files")
	codeRefused          = "refused"          // this side's prompt said no or got no answer ("refused files")
	codeRoomFull         = "roomFull"         // the relay room for this code already has two peers
	codeBadPassword      = "badPassword"      // the relay rejected the relay password
	codeWrongCode        = "wrongCode"        // both peers met but the code phrases differ (PAKE failed)
	codeCancelled        = "cancelled"        // this side cancelled
	codeConnectionLost   = "connectionLost"   // the connection dropped mid-transfer
	codeStoreLimit       = "storeLimit"       // stored transfer: the server's size, file-count, download, quota or rate limit
	codeStoreExpired     = "storeExpired"     // stored transfer: the server no longer has it (expired, revoked, used up)
	codeOther            = "other"
)

// codedError gives an error raised by this package its code directly, so it
// never depends on message text.
type codedError struct {
	code string
	err  error
}

func (e *codedError) Error() string { return e.err.Error() }
func (e *codedError) Unwrap() error { return e.err }

type failure struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func failureJSON(code, message string) string {
	b, _ := json.Marshal(failure{Code: code, Message: message})
	return string(b)
}

func errorJSON(err error) string { return failureJSON(classify(err), err.Error()) }

// startError carries the failure payload across gobind, which hands Swift only
// the error's text (NSError.localizedDescription), so both failure paths decode
// the same way.
func startError(err error) error {
	if err == nil {
		return nil
	}
	return errors.New(errorJSON(err))
}

// classify maps an error from croc or this package to a failure code. croc
// exports sentinels for relay failures only; everything else is matched on the
// text croc v11.5.4 produces (errors_test.go pins each one against a real croc
// client where it can). Order matters: a peer's refusal also cancels croc's
// context, and a bad relay password is reported as "could not connect to".
func classify(err error) string {
	var coded *codedError
	if errors.As(err, &coded) {
		return coded.code
	}
	var httpErr *storeclient.HTTPError
	if errors.As(err, &httpErr) {
		if code := storeHTTPCode(httpErr); code != "" {
			return code
		}
	}
	m := strings.ToLower(err.Error())
	switch {
	case strings.Contains(m, "unsupported pake protocol version"):
		return codePeerVersion
	case strings.Contains(m, "refusing files"):
		return codeDeclined
	case strings.Contains(m, "refused files"):
		return codeRefused
	case errors.Is(err, context.Canceled):
		return codeCancelled
	// A relay's only non-ok, non-rate-limit admission answer is "room full"; the
	// control connection reports it as "relay admission rejected".
	case strings.Contains(m, "room full"), strings.Contains(m, "relay admission rejected"):
		return codeRoomFull
	case strings.Contains(m, "bad password"):
		return codeBadPassword
	case strings.Contains(m, "password mismatch"),
		strings.Contains(m, "could not secure channel"),
		strings.Contains(m, "pake not successful"),
		strings.Contains(m, "message authentication failed"):
		return codeWrongCode
	case errors.Is(err, croc.ErrRelayConnection),
		errors.Is(err, croc.ErrDERPConnection),
		errors.Is(err, tcp.ErrAdmissionLimited),
		strings.Contains(m, "rate limited"),
		strings.Contains(m, "could not connect to"),
		strings.Contains(m, "no such host"),
		strings.Contains(m, "connection refused"),
		strings.Contains(m, "i/o timeout"),
		strings.Contains(m, "dial tcp"):
		return codeRelayUnreachable
	case errors.Is(err, io.ErrUnexpectedEOF),
		errors.Is(err, syscall.ECONNRESET),
		errors.Is(err, syscall.EPIPE),
		strings.Contains(m, "transfer disconnected"),
		strings.Contains(m, "broken pipe"),
		strings.Contains(m, "connection reset"),
		strings.Contains(m, "unexpected eof"):
		return codeConnectionLost
	}
	return codeOther
}

// storeHTTPCode maps a stored-transfer server's refusal to a failure code, or
// "" for statuses with no code of their own. The server answers 400 "invalid
// stored-transfer declaration" for a size, file count, download count or
// lifetime outside its configuration, the same refusal as 413 and 507.
func storeHTTPCode(e *storeclient.HTTPError) string {
	switch e.StatusCode {
	case http.StatusNotFound, http.StatusGone:
		return codeStoreExpired
	case http.StatusRequestEntityTooLarge, http.StatusTooManyRequests, http.StatusInsufficientStorage:
		return codeStoreLimit
	case http.StatusBadRequest:
		if strings.Contains(strings.ToLower(e.Message), "declaration") {
			return codeStoreLimit
		}
	}
	return ""
}
