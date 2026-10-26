package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/schollz/croc/v11/src/croc"
	"github.com/schollz/croc/v11/src/tcp"
)

const testRelayPassword = "pass123"

// startTestRelay runs a real croc relay (control port plus two data ports) on
// localhost for the length of the test.
func startTestRelay(t *testing.T) string {
	t.Helper()
	ports := make([]string, 3)
	for i := range ports {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		ports[i] = strconv.Itoa(l.Addr().(*net.TCPAddr).Port)
		l.Close()
	}
	ctx, cancel := context.WithCancel(context.Background())
	var wg sync.WaitGroup
	t.Cleanup(func() {
		cancel()
		wg.Wait()
	})
	for i, port := range ports {
		banner := []string{}
		if i == 0 {
			banner = append(banner, strings.Join(ports[1:], ","))
		}
		wg.Go(func() { _ = tcp.RunCtx(ctx, "warn", "127.0.0.1", port, testRelayPassword, banner...) })
	}
	deadline := time.Now().Add(5 * time.Second)
	for _, port := range ports {
		for {
			conn, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", port), 50*time.Millisecond)
			if err == nil {
				conn.Close()
				break
			}
			if time.Now().After(deadline) {
				t.Fatalf("test relay port %s: %v", port, err)
			}
			time.Sleep(10 * time.Millisecond)
		}
	}
	return net.JoinHostPort("127.0.0.1", ports[0])
}

func testClientOptions(sender bool, relay, password, secret string) croc.Options {
	return croc.Options{
		IsSender: sender, SharedSecret: secret, RelayAddress: relay, RelayPassword: password,
		Curve: "p256", HashAlgorithm: "xxhash", DisableLocal: true, NoPrompt: true,
		IgnoreStdin: true, DisableClipboard: true, NoMultiplexing: true,
	}
}

// runClient runs one real croc client to completion and returns its error.
func runClient(t *testing.T, ctx context.Context, o croc.Options) error {
	t.Helper()
	c, err := croc.NewCtx(ctx, o)
	if err != nil {
		t.Fatalf("croc.NewCtx: %v", err)
	}
	if !o.IsSender {
		return c.Receive()
	}
	f := filepath.Join(t.TempDir(), "f.txt")
	if err := os.WriteFile(f, []byte("hi"), 0o644); err != nil {
		t.Fatal(err)
	}
	files, empty, folders, err := croc.GetFilesInfo([]string{f}, false, false, nil)
	if err != nil {
		t.Fatal(err)
	}
	return c.Send(files, empty, folders)
}

func timeout(t *testing.T, d time.Duration) context.Context {
	ctx, cancel := context.WithTimeout(context.Background(), d)
	t.Cleanup(cancel)
	return ctx
}

func wantCode(t *testing.T, name string, err error, want string) {
	t.Helper()
	if err == nil {
		t.Fatalf("%s: no error, want code %s", name, want)
	}
	if got := classify(err); got != want {
		t.Errorf("%s: classify(%q) = %s, want %s", name, err, got, want)
	}
}

// Errors produced by real croc clients against a real local relay, so a croc
// bump that changes their text or wrapping fails here.
func TestClassifyLiveCrocErrors(t *testing.T) {
	relay := startTestRelay(t)

	t.Run("bad relay password", func(t *testing.T) {
		err := runClient(t, timeout(t, 10*time.Second), testClientOptions(false, relay, "wrong", "alpha-bravo-charlie"))
		wantCode(t, "receive", err, codeBadPassword)
	})

	t.Run("relay unreachable", func(t *testing.T) {
		recv := runClient(t, timeout(t, 10*time.Second), testClientOptions(false, "127.0.0.1:1", testRelayPassword, "alpha-bravo-charlie"))
		wantCode(t, "receive", recv, codeRelayUnreachable)
		send := runClient(t, timeout(t, 20*time.Second), testClientOptions(true, "127.0.0.1:1", testRelayPassword, "alpha-bravo-charlie"))
		wantCode(t, "send", send, codeRelayUnreachable)
		if !errors.Is(send, croc.ErrRelayConnection) {
			t.Errorf("send error %q no longer wraps croc.ErrRelayConnection", send)
		}
	})

	t.Run("wrong code in the same room", func(t *testing.T) {
		ctx := timeout(t, 20*time.Second)
		sendErr := make(chan error, 1)
		go func() {
			sendErr <- runClient(t, ctx, testClientOptions(true, relay, testRelayPassword, "kilo-bravo-charlie"))
		}()
		time.Sleep(500 * time.Millisecond)
		recv := runClient(t, ctx, testClientOptions(false, relay, testRelayPassword, "kilo-delta-echo"))
		wantCode(t, "receive", recv, codeWrongCode)
		wantCode(t, "send", <-sendErr, codeWrongCode)
	})

	t.Run("local cancel", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		time.AfterFunc(500*time.Millisecond, cancel)
		err := runClient(t, ctx, testClientOptions(false, relay, testRelayPassword, "lima-bravo-charlie"))
		wantCode(t, "receive", err, codeCancelled)
	})

	// The receiver's local probe (sent only with LAN on) times out before the
	// sender joins, and the sender's late answer to it breaks the receiver.
	// What the sender sees depends on its own LAN setting (a CLI sender with
	// LAN on fails with "could not secure channel"), so it is only stopped.
	t.Run("receiver joined before the sender", func(t *testing.T) {
		recv := testClientOptions(false, relay, testRelayPassword, "oscar-bravo-charlie")
		recv.DisableLocal = false
		recvErr := make(chan error, 1)
		go func() { recvErr <- runClient(t, timeout(t, 20*time.Second), recv) }()
		time.Sleep(1500 * time.Millisecond)
		sendCtx, stopSend := context.WithCancel(context.Background())
		sendDone := make(chan struct{})
		go func() {
			defer close(sendDone)
			_ = runClient(t, sendCtx, testClientOptions(true, relay, testRelayPassword, "oscar-bravo-charlie"))
		}()
		wantCode(t, "receive", <-recvErr, codeJoinedEarly)
		stopSend()
		<-sendDone
	})

	// Through croc's control-connection call, the one its clients use.
	t.Run("room full", func(t *testing.T) {
		for i := range 2 {
			c, _, _, _, err := tcp.ConnectToTCPServerControl(relay, testRelayPassword, "mike", 5*time.Second)
			if err != nil {
				t.Fatalf("peer %d: %v", i, err)
			}
			t.Cleanup(c.Close)
		}
		_, _, _, _, err := tcp.ConnectToTCPServerControl(relay, testRelayPassword, "mike", 5*time.Second)
		wantCode(t, "third peer", err, codeRoomFull)
	})
}

// Errors croc only produces with a peer we cannot run in-process (a v10 peer,
// a prompt answered on fd 0) or at an exact network moment. The text is copied
// from croc v11.5.5; verify-interop.sh covers the first three end to end.
func TestClassifyCrocErrorText(t *testing.T) {
	cases := []struct {
		err  error
		want string
	}{
		{errors.New("pake not successful: peer uses unsupported PAKE protocol version 0; upgrade both croc clients"), codePeerVersion},
		{errors.New("peer error: refusing files"), codeDeclined},
		{errors.New("refused files"), codeRefused},
		{fmt.Errorf("could not connect: %w", tcp.ErrAdmissionLimited), codeRelayUnreachable},
		{fmt.Errorf("data path: %w", croc.ErrDERPConnection), codeRelayUnreachable},
		{fmt.Errorf("transfer disconnected: %w", io.ErrUnexpectedEOF), codeConnectionLost},
		{fmt.Errorf("write: %w", syscall.EPIPE), codeConnectionLost},
		{errors.New("transfer disconnected after 3 reconnect attempts: missing reconnect room"), codeConnectionLost},
		{context.Canceled, codeCancelled},
		{errors.New("problem with decoding: decompress message: decompress data: flate: corrupt input before offset 6\nclose decompressor: flate: corrupt input before offset 6"), codeJoinedEarly},
		{errors.New("received archive failed validation or extraction"), codeOther},
	}
	for _, c := range cases {
		if got := classify(c.err); got != c.want {
			t.Errorf("classify(%q) = %s, want %s", c.err, got, c.want)
		}
	}
}

func TestNoPublicRelayHasItsOwnCode(t *testing.T) {
	t.Cleanup(forgetPublicRelay)
	forgetPublicRelay()
	down := func(context.Context, string, time.Duration) (time.Duration, error) {
		return 0, errors.New("unreachable")
	}
	_, err := generatePublicCode(context.Background(), down)
	wantCode(t, "generatePublicCode", fmt.Errorf("could not generate code phrase: %w", err), codeNoPublicRelay)
}

func decodeFailure(t *testing.T, payload string) failure {
	t.Helper()
	var keys map[string]any
	if err := json.Unmarshal([]byte(payload), &keys); err != nil {
		t.Fatalf("payload %q is not JSON: %v", payload, err)
	}
	assertKeys(t, keys, "code", "message")
	var f failure
	_ = json.Unmarshal([]byte(payload), &f)
	return f
}

func TestRunReportsFailurePayload(t *testing.T) {
	d := &errorDelegate{}
	pollDone := make(chan struct{})
	close(pollDone)
	s := &session{delegate: d, done: make(chan struct{}), pollDone: pollDone}

	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// run restores the working directory; a throwaway dir here would leave the
	// whole test binary in a deleted cwd.
	s.run(func() error { return errors.New("peer error: refusing files") }, wd, func() {})

	if len(d.errors) != 1 {
		t.Fatalf("OnError calls = %v, want one", d.errors)
	}
	if f := decodeFailure(t, d.errors[0]); f.Code != codeDeclined || f.Message != "peer error: refusing files" {
		t.Errorf("payload = %+v", f)
	}
}

func TestReportPanicPayloadIsOther(t *testing.T) {
	d := &errorDelegate{}
	reportPanic(&session{delegate: d}, "boom")
	if len(d.errors) != 1 {
		t.Fatalf("OnError calls = %v, want one", d.errors)
	}
	if f := decodeFailure(t, d.errors[0]); f.Code != codeOther || !strings.HasPrefix(f.Message, "croc panic: boom") {
		t.Errorf("payload = %+v", f)
	}
}

func TestStartErrorsCarryPayload(t *testing.T) {
	_, err := StartReceive("short", NewOptionsDefault(), &errorDelegate{})
	if err == nil {
		t.Fatal("StartReceive with a short code: want error")
	}
	if f := decodeFailure(t, err.Error()); f.Code != codeOther || !strings.Contains(f.Message, "too short") {
		t.Errorf("payload = %+v", f)
	}
	if startError(nil) != nil {
		t.Error("startError(nil) != nil")
	}
}

func FuzzClassify(f *testing.F) {
	for _, s := range []string{
		"pake not successful: peer uses unsupported PAKE protocol version 0",
		"peer error: refusing files", "refused files", "room full", "bad password",
		"could not connect to relay", "transfer disconnected", "unexpected EOF", "",
	} {
		f.Add(s)
	}
	codes := []string{
		codePeerVersion, codeRelayUnreachable, codeNoPublicRelay, codeDeclined, codeRefused,
		codeRoomFull, codeBadPassword, codeWrongCode, codeCancelled, codeConnectionLost,
		codeStoreLimit, codeStoreExpired, codeInvalidSetting, codeOther,
	}
	f.Fuzz(func(t *testing.T, msg string) {
		err := errors.New(msg)
		got := classify(err)
		if !slices.Contains(codes, got) {
			t.Fatalf("classify(%q) = %q, not a known failure code", msg, got)
		}
		if classify(err) != got {
			t.Fatalf("classify(%q) is not deterministic", msg)
		}
		// Wrapping must not change the code: the app relies on errors.As/Is and
		// on text matching seeing through croc's own wrapping.
		if w := classify(fmt.Errorf("wrapped: %w", err)); w != got && w != codeCancelled {
			t.Fatalf("classify(wrapped %q) = %s, want %s", msg, w, got)
		}
		// A coded error carries its code regardless of its text.
		if c := classify(&codedError{codeInvalidSetting, err}); c != codeInvalidSetting {
			t.Fatalf("classify(coded, %q) = %s, want %s", msg, c, codeInvalidSetting)
		}
		// The failure payload must round-trip through JSON for any message.
		var f failure
		if jerr := json.Unmarshal([]byte(errorJSON(err)), &f); jerr != nil || f.Code != got {
			t.Fatalf("errorJSON(%q) decoded to %+v, %v; want code %s", msg, f, jerr, got)
		}
	})
}
