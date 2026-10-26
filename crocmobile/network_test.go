package crocmobile

import (
	"encoding/json"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/schollz/croc/v11/src/comm"
	"github.com/schollz/croc/v11/src/store"
)

func TestRelayPorts(t *testing.T) {
	want := []string{"9009", "9010", "9011", "9012", "9013"}
	got := relayPorts()
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("relayPorts = %v, want croc's defaults %v", got, want)
	}
	// croc rewrites Options.RelayPorts in place during a transfer, so each
	// call must hand out its own slice.
	got[0] = "1"
	if again := relayPorts(); !reflect.DeepEqual(again, want) {
		t.Fatalf("relayPorts after a caller changed its result = %v, want %v", again, want)
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

// settingCases is, per ValidateSetting field, what the engine accepts and
// refuses. The app keeps no copy of these rules: its settings form asks the
// engine.
var settingCases = []struct {
	field   string
	valid   []string
	invalid []string
}{
	{
		SettingSocks5Proxy,
		[]string{
			"", "   ", "127.0.0.1:1080", "proxy.example:1080", "socks5://user:secret@proxy.example:1080",
			"socks5h://proxy.example:1080", "SOCKS5://proxy.example:1080", " socks5://proxy.example:1080 ",
			"socks5://[::1]:1080",
		},
		[]string{
			"proxy.example", "http://user:secret@proxy.example:1080", "socks5://:1080",
			"user:secret@proxy.example", "socks5://proxy.example", "proxy.example:port", "proxy.example:0",
			"proxy.example:70000", "socks5://proxy.example:1080 extra", "::1:1080", "socks5://host:1080:2",
			"socks5:host:1080",
		},
	},
	{
		SettingHTTPProxy,
		[]string{
			"", "proxy.example:3128", "http://user:secret@proxy.example:3128", " https://proxy.example:443 ",
			"https://proxy.example:443/", "http://[::1]:3128",
		},
		[]string{
			"socks5://user:secret@proxy.example:1080", "user:secret@proxy.example", "proxy.example",
			"ftp://proxy.example:21", "http://:3128", "::1:3128", "http://host:3128:2",
		},
	},
	{
		SettingMulticastAddress,
		[]string{"", "239.255.255.250", "224.0.0.251", "239.255.255.255", " 224.0.0.1 "},
		[]string{
			"10.0.0.1", "ff02::1", "not an address", "223.255.255.255", "240.0.0.0", "239.255.255",
			"239.255.255.256", "239.255.255.250.1", "239.255.255.0250",
		},
	},
	{
		SettingPeerIP,
		[]string{"", "10.0.0.1:9009", "[::1]:9009", " 192.168.1.20:65535 ", "[fe80::1]:1"},
		[]string{
			"10.0.0.1", "sender.local:9009", "10.0.0.1:0", "10.0.0.1:http", "10.0.0.1:65536", "::1:9009",
			"[::1]", "[::1]9009", "[not-ip]:9009", "[fe80::1%en0]:9009", ":9009",
		},
	},
	{
		SettingThrottleUpload,
		[]string{"", "  ", "500k", "500K", "2m", "2M", "1g", "1G", "1000", "10", "99k"},
		[]string{
			"k", "xk", "5", "0k", "0", "00", "-5k", "+5k", "1.5m", "5kb", "5 k", "fast",
			"99999999999999999999k", "٣k",
		},
	},
	{
		SettingStoreServer,
		[]string{
			"https://getcroc.com", "https://getcroc.com/", "  https://example.org:8443  ",
			"http://localhost:8080", "http://127.0.0.1:9", "http://[::1]:8080",
		},
		[]string{
			"http://example.com", "http://localhost.example.com", "ftp://getcroc.com", "getcroc.com", "", "   ",
			"https://", "https://getcroc.com/s/abc", "https://getcroc.com?x=1", "https://getcroc.com#frag",
			"https://user:pw@getcroc.com",
		},
	},
}

func TestValidateSetting(t *testing.T) {
	for _, c := range settingCases {
		for _, v := range c.valid {
			if err := ValidateSetting(c.field, v); err != nil {
				t.Errorf("ValidateSetting(%s, %q) = %v, want nil", c.field, v, err)
			}
		}
		for _, v := range c.invalid {
			err := ValidateSetting(c.field, v)
			if got := payloadCode(err); got != codeInvalidSetting {
				t.Errorf("ValidateSetting(%s, %q) = %v, want a %s payload", c.field, v, err, codeInvalidSetting)
			}
		}
	}
}

// payloadCode decodes the failure payload ValidateSetting returns, or "" for nil
// or for text that is not a payload.
func payloadCode(err error) string {
	var f failure
	if err == nil || json.Unmarshal([]byte(err.Error()), &f) != nil {
		return ""
	}
	return f.Code
}

func TestValidateSettingCoversEverySetting(t *testing.T) {
	fields := []string{
		SettingSocks5Proxy, SettingHTTPProxy, SettingThrottleUpload, SettingMulticastAddress, SettingPeerIP,
		SettingStoreServer,
	}
	if len(settingChecks) != len(fields) || len(settingCases) != len(fields) {
		t.Fatalf("%d checks and %d case tables for %d settings", len(settingChecks), len(settingCases), len(fields))
	}
	for _, f := range fields {
		if settingChecks[f] == nil {
			t.Errorf("no check for %s", f)
		}
	}
	// The names are the Options and StoreOptions fields, so Swift and Go read the same word.
	for _, f := range fields {
		_, inOptions := reflect.TypeOf(Options{}).FieldByName(f)
		_, inStoreOptions := reflect.TypeOf(StoreOptions{}).FieldByName(strings.TrimPrefix(f, "Store"))
		if !inOptions && (!strings.HasPrefix(f, "Store") || !inStoreOptions) {
			t.Errorf("%q is not an Options field or a Store-prefixed StoreOptions field", f)
		}
	}
}

// A transfer start and a settings form must never disagree: for every value in
// the tables, the start's own check and ValidateSetting accept or refuse alike.
func TestValidateSettingMatchesTransferStart(t *testing.T) {
	starts := map[string]func(v string) error{
		SettingSocks5Proxy:      func(v string) error { return validateNetworkOptions(&Options{Socks5Proxy: v}) },
		SettingHTTPProxy:        func(v string) error { return validateNetworkOptions(&Options{HTTPProxy: v}) },
		SettingThrottleUpload:   func(v string) error { return validateNetworkOptions(&Options{ThrottleUpload: v}) },
		SettingMulticastAddress: func(v string) error { return validateNetworkOptions(&Options{MulticastAddress: v}) },
		SettingPeerIP:           func(v string) error { return validateNetworkOptions(&Options{PeerIP: v}) },
		SettingStoreServer:      validateStoreOrigin,
	}
	for _, c := range settingCases {
		for _, v := range append(slices.Clone(c.valid), c.invalid...) {
			start, setting := starts[c.field](v), ValidateSetting(c.field, v)
			if (start == nil) != (setting == nil) {
				t.Errorf("%s %q: transfer start = %v, ValidateSetting = %v", c.field, v, start, setting)
			}
		}
	}
}

func TestValidateSettingUnknownField(t *testing.T) {
	for _, field := range []string{"", "socks5Proxy", "Server", "OutDir", "Code"} {
		err := ValidateSetting(field, "x")
		if payloadCode(err) != codeOther {
			t.Errorf("ValidateSetting(%q) = %v, want a %s payload", field, err, codeOther)
		}
	}
}

// A proxy URL can carry a password, so no refusal may repeat any part of it,
// including the refusals that come from url.Parse.
func TestValidateSettingNeverQuotesAProxy(t *testing.T) {
	values := []string{
		"socks5://user:hunter2@nohost", "http://user:hunter2@nohost:1080", "user:hunter2@nohost:1080",
		"socks5://user:hunter2@[bad:1080", "https://user:hunter2@nohost:99999", "ftp://user:hunter2@nohost:21",
		"socks5://user:hunter2@nohost:1080 extra", "socks5://user:hunter2@:1080",
	}
	for _, field := range []string{SettingSocks5Proxy, SettingHTTPProxy} {
		for _, v := range values {
			err := ValidateSetting(field, v)
			if err == nil {
				continue
			}
			if payloadCode(err) != codeInvalidSetting {
				t.Errorf("ValidateSetting(%s, %q) = %v, want a %s payload", field, v, err, codeInvalidSetting)
			}
			for _, leak := range []string{"hunter2", "nohost"} {
				if strings.Contains(err.Error(), leak) {
					t.Errorf("ValidateSetting(%s, %q) error %q quotes %q", field, v, err, leak)
				}
			}
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
}

func readNetworkGlobals() networkGlobals {
	return networkGlobals{comm.Socks5Proxy, comm.HttpProxy}
}

var proxiedOptions = Options{Socks5Proxy: "203.0.113.1:1080", HTTPProxy: "203.0.113.2:3128"}

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
	if left, _ := filepath.Glob(filepath.Join(o.WorkDir, "croc-stdin-*")); len(left) != 0 {
		t.Errorf("text temp file left behind after the panic: %v", left)
	}
}

// A transfer holds its proxy settings for its whole run, and puts the
// previous ones back when it ends (here, cancelled while it waits for a peer).
func TestNetworkGlobalsHeldForTheTransfer(t *testing.T) {
	before := readNetworkGlobals()
	o := proxiedOptions
	o.OnlyLocal = true
	o.WorkDir = t.TempDir()
	rec := newStoreRecorder()
	tr, err := StartSend("", "hello", &o, rec)
	if err != nil {
		t.Fatalf("StartSend: %v", err)
	}
	want := networkGlobals{proxiedOptions.Socks5Proxy, proxiedOptions.HTTPProxy}
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

var throttleSpeed = regexp.MustCompile(`^[0-9]+[kKmMgG]?$`)

func FuzzValidateThrottle(f *testing.F) {
	for _, s := range []string{"", "500k", " 2M ", "1g", "12", "5", "0k", "k", "kk", "-5k", "+5k", "5kb", "1.5m"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, value string) {
		err := validateThrottle(value)
		if err != nil {
			if codeOf(err) != codeInvalidSetting {
				t.Fatalf("validateThrottle(%q) err = %v, want %s", value, err, codeInvalidSetting)
			}
			return
		}
		v := strings.TrimSpace(value)
		if v == "" {
			return
		}
		// croc panics on anything but digits plus one optional unit letter, on
		// zero, and ignores a one-character value.
		if len(v) < 2 || !throttleSpeed.MatchString(v) || strings.Trim(v, "0kKmMgG") == "" {
			t.Fatalf("validateThrottle(%q) accepted a value croc cannot parse", value)
		}
	})
}

func FuzzProxyURL(f *testing.F) {
	for _, s := range []string{
		"", "127.0.0.1:1080", "proxy.example:3128", "socks5://user:secret@proxy.example:1080",
		"socks5h://proxy.example:1080", "http://user:secret@proxy.example:3128", " https://proxy.example:443 ",
		"proxy.example", "socks5://:1080", "user:secret@proxy.example", "proxy.example:0", "proxy.example:70000",
		"::1:1080", "socks5://host:1080:2", "socks5://[::1]:1080",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, value string) {
		for _, c := range []struct {
			scheme  string
			allowed []string
		}{
			{"socks5", []string{"socks5", "socks5h"}},
			{"http", []string{"http", "https"}},
		} {
			u, err := proxyURL(value, c.scheme, c.allowed...)
			if err != nil {
				if u != nil || codeOf(err) != codeInvalidSetting {
					t.Fatalf("proxyURL(%q, %s) = %v, %v; want nil and %s", value, c.scheme, u, err, codeInvalidSetting)
				}
				continue
			}
			if u == nil {
				if strings.TrimSpace(value) != "" {
					t.Fatalf("proxyURL(%q, %s) = nil, nil for a non-empty value", value, c.scheme)
				}
				continue
			}
			port, perr := strconv.Atoi(u.Port())
			if !slices.Contains(c.allowed, u.Scheme) || u.Hostname() == "" || perr != nil || port < 1 || port > 65535 {
				t.Fatalf("proxyURL(%q, %s) accepted %q: scheme, host or port invalid", value, c.scheme, u)
			}
			if strings.Contains(u.Hostname(), ":") && !strings.HasPrefix(u.Host, "[") {
				t.Fatalf("proxyURL(%q, %s) accepted %q: host has an unbracketed colon", value, c.scheme, u)
			}
		}
	})
}
