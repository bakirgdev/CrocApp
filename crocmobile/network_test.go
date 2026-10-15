package crocmobile

import (
	"encoding/json"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/schollz/croc/v11/src/comm"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/store"
)

func TestRelayPorts(t *testing.T) {
	tests := []struct {
		name            string
		base, transfers int
		want            []string
	}{
		{"croc defaults", 0, 0, []string{"9009", "9010", "9011", "9012", "9013"}},
		{"custom", 9100, 2, []string{"9100", "9101", "9102"}},
		{"one transfer", 50000, 1, []string{"50000", "50001"}},
		{"top of range", 65533, 2, []string{"65533", "65534", "65535"}},
	}
	for _, tt := range tests {
		got, err := relayPorts(&Options{BasePort: tt.base, Transfers: tt.transfers})
		if err != nil || !reflect.DeepEqual(got, tt.want) {
			t.Errorf("%s: relayPorts = %v, %v; want %v", tt.name, got, err, tt.want)
		}
	}
	for _, o := range []Options{{BasePort: -1}, {Transfers: -1}, {BasePort: 65535}, {BasePort: 65534, Transfers: 2}} {
		if _, err := relayPorts(&o); codeOf(err) != codeInvalidSetting {
			t.Errorf("relayPorts(%+v) err = %v, want %s", o, err, codeInvalidSetting)
		}
	}
}

func TestValidateNetworkOptions(t *testing.T) {
	valid := []Options{
		{},
		{Socks5Proxy: "127.0.0.1:1080", HTTPProxy: "proxy.example:3128"},
		{Socks5Proxy: "socks5://user:secret@proxy.example:1080"},
		{Socks5Proxy: "socks5h://proxy.example:1080"},
		{HTTPProxy: "http://user:secret@proxy.example:3128"},
		{HTTPProxy: " https://proxy.example:443 "},
		{MulticastAddress: "239.255.255.250"},
		{MulticastAddress: "224.0.0.251"},
		{PeerIP: "10.0.0.1:9009"},
		{PeerIP: "[::1]:9009"},
		{ThrottleUpload: "500k"},
		{ThrottleUpload: " 2M "},
		{ThrottleUpload: "1g"},
		{ThrottleUpload: "12"},
	}
	for _, o := range valid {
		if err := validateNetworkOptions(&o); err != nil {
			t.Errorf("validateNetworkOptions(%+v) = %v, want nil", o, err)
		}
	}
	invalid := []Options{
		{Socks5Proxy: "proxy.example"},
		{Socks5Proxy: "http://user:secret@proxy.example:1080"},
		{Socks5Proxy: "socks5://:1080"},
		{HTTPProxy: "socks5://user:secret@proxy.example:1080"},
		{HTTPProxy: "user:secret@proxy.example"},
		{MulticastAddress: "10.0.0.1"},
		{MulticastAddress: "ff02::1"},
		{MulticastAddress: "not an address"},
		{PeerIP: "10.0.0.1"},
		{PeerIP: "sender.local:9009"},
		{PeerIP: "10.0.0.1:0"},
		{PeerIP: "10.0.0.1:http"},
		{Socks5Proxy: "proxy.example:0"},
		{HTTPProxy: "proxy.example:70000"},
		{ThrottleUpload: "5"},
		{ThrottleUpload: "0k"},
		{ThrottleUpload: "k"},
		{ThrottleUpload: "kk"},
		{ThrottleUpload: "-5k"},
		{ThrottleUpload: "+5k"},
		{ThrottleUpload: "5kb"},
		{ThrottleUpload: "1.5m"},
	}
	for _, o := range invalid {
		err := validateNetworkOptions(&o)
		if codeOf(err) != codeInvalidSetting {
			t.Errorf("validateNetworkOptions(%+v) = %v, want %s", o, err, codeInvalidSetting)
			continue
		}
		if strings.Contains(err.Error(), "secret") {
			t.Errorf("error %q quotes the proxy credentials", err)
		}
	}
}

func TestInvalidSettingFailsBeforeTheLock(t *testing.T) {
	_, err := StartSend("", "hello", &Options{Socks5Proxy: "socks5://user:secret@nohost"}, newStoreRecorder())
	if err == nil || !strings.Contains(err.Error(), codeInvalidSetting) || strings.Contains(err.Error(), "secret") {
		t.Fatalf("StartSend err = %v, want a coded %s without the credentials", err, codeInvalidSetting)
	}
	if comm.Socks5Proxy != "" {
		t.Fatalf("comm.Socks5Proxy = %q after a refused start", comm.Socks5Proxy)
	}
	if !activeMu.TryLock() {
		t.Fatal("lock held after a refused start")
	}
	activeMu.Unlock()
}

type networkGlobals struct {
	socks5, httpProxy string
	internalDNS       bool
}

func readNetworkGlobals() networkGlobals {
	return networkGlobals{comm.Socks5Proxy, comm.HttpProxy, models.INTERNAL_DNS}
}

var proxiedOptions = Options{Socks5Proxy: "203.0.113.1:1080", HTTPProxy: "203.0.113.2:3128", InternalDNS: true}

func assertGlobalsRestored(t *testing.T, before networkGlobals) {
	t.Helper()
	if got := readNetworkGlobals(); got != before {
		t.Fatalf("network globals = %+v, want them restored to %+v", got, before)
	}
	if !activeMu.TryLock() {
		t.Fatal("lock still held")
	}
	activeMu.Unlock()
}

func TestNetworkGlobalsRestoredAfterStartError(t *testing.T) {
	before := readNetworkGlobals()
	o := proxiedOptions
	o.OnlyLocal = true
	if _, err := StartSend(filepath.Join(t.TempDir(), "missing"), "", &o, newStoreRecorder()); err == nil {
		t.Fatal("StartSend of a missing file succeeded")
	}
	assertGlobalsRestored(t, before)
}

type panickingCodeDelegate struct{ *storeRecorder }

func (panickingCodeDelegate) OnCodeReady(string) { panic("delegate panic") }

func TestNetworkGlobalsRestoredAfterPanic(t *testing.T) {
	before := readNetworkGlobals()
	o := proxiedOptions
	o.OnlyLocal = true
	o.WorkDir = t.TempDir()
	_, err := StartSend("", "hello", &o, panickingCodeDelegate{newStoreRecorder()})
	if err == nil || !strings.Contains(err.Error(), "delegate panic") {
		t.Fatalf("StartSend err = %v, want the delegate panic", err)
	}
	assertGlobalsRestored(t, before)
}

// A transfer holds its proxy and DNS settings for its whole run, and puts the
// previous ones back when it ends (here, cancelled while it waits for a peer).
func TestNetworkGlobalsHeldForTheTransfer(t *testing.T) {
	before := readNetworkGlobals()
	o := proxiedOptions
	o.OnlyLocal = true
	o.BasePort = 47100
	o.Transfers = 2
	o.WorkDir = t.TempDir()
	rec := newStoreRecorder()
	tr, err := StartSend("", "hello", &o, rec)
	if err != nil {
		t.Fatalf("StartSend: %v", err)
	}
	want := networkGlobals{proxiedOptions.Socks5Proxy, proxiedOptions.HTTPProxy, true}
	if got := readNetworkGlobals(); got != want {
		t.Errorf("during the transfer: network globals = %+v, want %+v", got, want)
	}
	tr.Cancel()
	rec.wait(t)
	assertGlobalsRestored(t, before)
}

// connectProxy is a minimal HTTP proxy for plain-http requests (the loopback
// store server), counting what it forwards.
func connectProxy(t *testing.T, forwarded *atomic.Int32) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		forwarded.Add(1)
		r.RequestURI = ""
		resp, err := http.DefaultTransport.RoundTrip(r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		for k, v := range resp.Header {
			w.Header()[k] = v
		}
		w.WriteHeader(resp.StatusCode)
		_, _ = io.Copy(w, resp.Body)
	})}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() { _ = srv.Close() })
	return ln.Addr().String()
}

func TestStoreCallsUseTheProxy(t *testing.T) {
	server := startTestStore(t, store.Config{})
	var forwarded atomic.Int32
	proxy := connectProxy(t, &forwarded)
	o := StoreOptions{HTTPProxy: proxy}

	rec, receipt := storeSend(t, server, o, writeFiles(t, t.TempDir(), map[string]string{"a.txt": "via proxy"}))
	if rec.errMsg != "" {
		t.Fatalf("upload through the proxy failed: %s", rec.errMsg)
	}
	uploads := forwarded.Load()
	if uploads == 0 {
		t.Fatal("the upload bypassed the proxy")
	}

	out := t.TempDir()
	recv := newStoreRecorder()
	tr, err := StartStoreReceive(receipt.Link, out, &o, recv)
	if err != nil {
		t.Fatal(err)
	}
	<-recv.fileReady
	tr.Respond(true, PolicyKeepBoth)
	recv.wait(t)
	if recv.errMsg != "" || readFile(t, filepath.Join(out, "a.txt")) != "via proxy" {
		t.Fatalf("download through the proxy: err %q", recv.errMsg)
	}
	downloads := forwarded.Load()
	if downloads == uploads {
		t.Fatal("the download bypassed the proxy")
	}

	if err := RevokeStored(receipt.Origin, receipt.ID, receipt.UploadToken, &o); err != nil {
		t.Fatalf("RevokeStored: %v", err)
	}
	if forwarded.Load() == downloads {
		t.Fatal("the revoke bypassed the proxy")
	}
}

func TestStoreClientPrefersSOCKS5AndRefusesRedirects(t *testing.T) {
	c, err := storeClient(&StoreOptions{Socks5Proxy: "127.0.0.1:1080", HTTPProxy: "127.0.0.1:3128"})
	if err != nil {
		t.Fatal(err)
	}
	req, _ := http.NewRequest(http.MethodGet, "https://getcroc.com/", nil)
	u, err := c.HTTP.Transport.(*http.Transport).Proxy(req)
	if err != nil || u == nil || u.String() != "socks5://127.0.0.1:1080" {
		t.Fatalf("proxy = %v, %v; want socks5://127.0.0.1:1080", u, err)
	}
	if c.HTTP.CheckRedirect(req, nil) == nil {
		t.Fatal("redirects are followed")
	}
	if _, err := storeClient(&StoreOptions{HTTPProxy: "user:secret@nohost"}); codeOf(err) != codeInvalidSetting {
		t.Fatalf("bad proxy: err = %v, want %s", err, codeInvalidSetting)
	}
}

func TestStartErrorPayloadForInvalidSetting(t *testing.T) {
	_, err := StartReceive("abcdef-code", &Options{OutDir: t.TempDir(), PeerIP: "nohost"}, newStoreRecorder())
	var f failure
	if err == nil || json.Unmarshal([]byte(err.Error()), &f) != nil || f.Code != codeInvalidSetting {
		t.Fatalf("StartReceive err = %v, want a %s payload", err, codeInvalidSetting)
	}
}

func codeOf(err error) string {
	if err == nil {
		return ""
	}
	return classify(err)
}
