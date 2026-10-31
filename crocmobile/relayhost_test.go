package crocmobile

import (
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// freePortBase returns a port whose next three ports are free on host too.
func freePortBase(t *testing.T, host string) int {
	t.Helper()
	for range 50 {
		l, err := net.Listen("tcp", net.JoinHostPort(host, "0"))
		if err != nil {
			t.Fatal(err)
		}
		base := l.Addr().(*net.TCPAddr).Port
		l.Close()
		if base+RelayPortCount > 65535 {
			continue
		}
		var held []net.Listener
		ok := true
		for i := range RelayPortCount {
			l, err := net.Listen("tcp", net.JoinHostPort(host, strconv.Itoa(base+i)))
			if err != nil {
				ok = false
				break
			}
			held = append(held, l)
		}
		for _, l := range held {
			l.Close()
		}
		if ok {
			return base
		}
	}
	t.Fatal("no free port range")
	return 0
}

func startHost(t *testing.T, host, password string) (*RelayHost, int) {
	t.Helper()
	base := freePortBase(t, host)
	h, err := StartRelay(host, base, password, nil)
	if err != nil {
		t.Fatalf("StartRelay: %v", err)
	}
	t.Cleanup(h.Stop)
	return h, base
}

func decodeCheck(t *testing.T, payload string) relayCheck {
	t.Helper()
	var c relayCheck
	if err := json.Unmarshal([]byte(payload), &c); err != nil {
		t.Fatalf("CheckRelay payload %q: %v", payload, err)
	}
	return c
}

// A plain croc client sends through the hosted relay and the app receives, as
// the croc v11 CLI would. Both peers cannot be app transfers: crocmobile runs
// one at a time per process.
func TestStartRelayServesCrocClients(t *testing.T) {
	_, base := startHost(t, "127.0.0.1", "hosted-secret")
	relay := net.JoinHostPort("127.0.0.1", strconv.Itoa(base))
	sendErr := make(chan error, 1)
	go func() {
		sendErr <- runClient(t, timeout(t, 30*time.Second), testClientOptions(true, relay, "hosted-secret", "hosted-relay-code"))
	}()
	time.Sleep(500 * time.Millisecond) // sender first (crocmobile-bridge.md, "Start order: sender first")

	out := t.TempDir()
	o := NewOptionsDefault()
	o.RelayAddress, o.RelayPassword, o.DisableLocal, o.OutDir, o.AutoAccept = relay, "hosted-secret", true, out, true
	got := newLifecycleRecorder()
	recv, err := StartReceive("hosted-relay-code", o, got)
	if err != nil {
		t.Fatal(err)
	}
	defer recv.Cancel()
	got.wait(t)
	if codes := got.terminalCodes(); len(codes) != 1 || codes[0] != "done" {
		t.Fatalf("receive ended %v, want done", codes)
	}
	if err := <-sendErr; err != nil {
		t.Fatalf("send through the hosted relay: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(out, "f.txt")); err != nil || string(b) != "hi" {
		t.Fatalf("received %q, %v", b, err)
	}
}

func TestStartRelayWrongPasswordFailsTheTransfer(t *testing.T) {
	_, base := startHost(t, "127.0.0.1", "hosted-secret")
	o := NewOptionsDefault()
	o.RelayAddress = net.JoinHostPort("127.0.0.1", strconv.Itoa(base))
	o.RelayPassword, o.DisableLocal, o.Code = "not-the-secret", true, "hosted-relay-code"
	rec := newLifecycleRecorder()
	send, err := StartSend("", "x", o, rec)
	if err != nil {
		t.Fatal(err)
	}
	defer send.Cancel()
	rec.wait(t)
	if codes := rec.terminalCodes(); len(codes) != 1 || codes[0] != codeBadPassword {
		t.Fatalf("send ended %v, want %s", codes, codeBadPassword)
	}
}

func TestStartRelayPortInUse(t *testing.T) {
	base := freePortBase(t, "127.0.0.1")
	taken, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(base+2)))
	if err != nil {
		t.Fatal(err)
	}
	defer taken.Close()
	_, err = StartRelay("127.0.0.1", base, "", nil)
	if got := startCode(t, err); got != codePortInUse {
		t.Fatalf("code = %s, want %s", got, codePortInUse)
	}
	// The ports bound before the clash are released again.
	l, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(base)))
	if err != nil {
		t.Fatalf("base port still held after a failed start: %v", err)
	}
	l.Close()
}

func TestStartRelayRefusesBadPorts(t *testing.T) {
	for _, port := range []int{0, -1, 65533, 65536} {
		_, err := StartRelay("127.0.0.1", port, "", nil)
		if got := startCode(t, err); got != codeInvalidSetting {
			t.Errorf("port %d: code = %s, want %s", port, got, codeInvalidSetting)
		}
	}
}

func TestRelayHostStopReleasesPortsAndRepeats(t *testing.T) {
	h, base := startHost(t, "127.0.0.1", "")
	if got, want := h.Ports(), strings.Join([]string{
		strconv.Itoa(base), strconv.Itoa(base + 1), strconv.Itoa(base + 2), strconv.Itoa(base + 3),
	}, ","); got != want {
		t.Fatalf("Ports() = %s, want %s", got, want)
	}
	h.Stop()
	h.Stop()
	for i := range RelayPortCount {
		l, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(base+i)))
		if err != nil {
			t.Fatalf("port %d still held after Stop: %v", base+i, err)
		}
		l.Close()
	}
}

func TestCheckRelay(t *testing.T) {
	_, base := startHost(t, "127.0.0.1", "hosted-secret")
	addr := net.JoinHostPort("127.0.0.1", strconv.Itoa(base))

	good := decodeCheck(t, CheckRelay(addr, "hosted-secret", "4"))
	if !good.Reachable || good.PasswordOK == nil || !*good.PasswordOK || good.Code != "" || good.LatencyMs <= 0 {
		t.Errorf("right password: %+v", good)
	}

	bad := decodeCheck(t, CheckRelay(addr, "wrong", "4"))
	if !bad.Reachable || bad.PasswordOK == nil || *bad.PasswordOK || bad.Code != codeBadPassword {
		t.Errorf("wrong password: %+v", bad)
	}

	// Blank means croc's default, which this relay does not use.
	blank := decodeCheck(t, CheckRelay(addr, "", "4"))
	if blank.Code != codeBadPassword {
		t.Errorf("blank password: %+v", blank)
	}

	// An IPv4 literal has no IPv6 address.
	if v6 := decodeCheck(t, CheckRelay(addr, "hosted-secret", "6")); v6.Code != codeNoAddress || v6.Reachable {
		t.Errorf("IPv6 of an IPv4 literal: %+v", v6)
	}
}

func TestCheckRelayUnreachableAndInvalid(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	closed := l.Addr().String()
	l.Close()
	if c := decodeCheck(t, CheckRelay(closed, "x", "4")); c.Reachable || c.Code != codeRelayUnreachable || c.PasswordOK != nil {
		t.Errorf("closed port: %+v", c)
	}
	for _, c := range []struct{ addr, family string }{{"no-port", "4"}, {":9009", "4"}, {"127.0.0.1:9009", "5"}} {
		if got := decodeCheck(t, CheckRelay(c.addr, "x", c.family)); got.Code != codeInvalidSetting {
			t.Errorf("CheckRelay(%q, %q): %+v", c.addr, c.family, got)
		}
	}
}

// A listener that accepts and says nothing is reachable but not a croc relay,
// so the password verdict stays open.
func TestCheckRelayNotACrocRelay(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()
	c := decodeCheck(t, CheckRelay(l.Addr().String(), "x", "4"))
	if !c.Reachable || c.PasswordOK != nil || c.Code != codeOther {
		t.Errorf("silent listener: %+v", c)
	}
}

func TestCheckRelayIPv6(t *testing.T) {
	l, err := net.Listen("tcp", "[::1]:0")
	if err != nil {
		t.Skip("no IPv6 loopback")
	}
	l.Close()
	h := freePortBase(t, "::1")
	host, err := StartRelay("::1", h, "v6-secret", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer host.Stop()
	c := decodeCheck(t, CheckRelay(net.JoinHostPort("::1", strconv.Itoa(h)), "v6-secret", "6"))
	if !c.Reachable || c.PasswordOK == nil || !*c.PasswordOK {
		t.Errorf("IPv6: %+v", c)
	}
}

// failingListener's Accept fails with a non-closed error once fail is closed,
// as a listener that dies by itself would.
type failingListener struct {
	net.Listener
	fail chan struct{}
}

func (l failingListener) Accept() (net.Conn, error) {
	select {
	case <-l.fail:
		return nil, errors.New("accept failed")
	default:
	}
	c := make(chan struct {
		conn net.Conn
		err  error
	}, 1)
	go func() {
		conn, err := l.Listener.Accept()
		c <- struct {
			conn net.Conn
			err  error
		}{conn, err}
	}()
	select {
	case r := <-c:
		return r.conn, r.err
	case <-l.fail:
		return nil, errors.New("accept failed")
	}
}

type stoppedRecorder struct{ got chan string }

func (r stoppedRecorder) OnRelayStopped(j string) { r.got <- j }

func TestRelayHostReportsAPortThatDiesAndStopsEverything(t *testing.T) {
	var listeners []net.Listener
	var ports []string
	fail := make(chan struct{})
	for i := range RelayPortCount {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		ports = append(ports, strconv.Itoa(l.Addr().(*net.TCPAddr).Port))
		if i == 2 {
			l = failingListener{Listener: l, fail: fail}
		}
		listeners = append(listeners, l)
	}
	rec := stoppedRecorder{got: make(chan string, 2)}
	h, err := serveRelay(listeners, ports, "", rec)
	if err != nil {
		t.Fatal(err)
	}
	defer h.Stop()
	close(fail)
	select {
	case j := <-rec.got:
		if code := decodeFailure(t, j).Code; code != codeOther {
			t.Fatalf("code = %s, want %s", code, codeOther)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no OnRelayStopped")
	}
	select {
	case <-h.done:
	case <-time.After(5 * time.Second):
		t.Fatal("the other ports kept running")
	}
	select {
	case j := <-rec.got:
		t.Fatalf("a second callback: %s", j)
	case <-time.After(200 * time.Millisecond):
	}
}

func TestRelayHostStopSilencesTheCallback(t *testing.T) {
	rec := stoppedRecorder{got: make(chan string, 1)}
	base := freePortBase(t, "127.0.0.1")
	h, err := StartRelay("127.0.0.1", base, "", rec)
	if err != nil {
		t.Fatal(err)
	}
	h.Stop()
	select {
	case j := <-rec.got:
		t.Fatalf("callback after Stop: %s", j)
	case <-time.After(300 * time.Millisecond):
	}
}
