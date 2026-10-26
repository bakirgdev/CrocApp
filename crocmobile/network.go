package crocmobile

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"unicode"

	"github.com/schollz/croc/v11/src/comm"
	"github.com/schollz/croc/v11/src/storeclient"
)

// croc CLI defaults the library does not apply itself (cli.go: --port,
// --transfers, --curve, --multicast). Curve and ports are fixed: neither is a
// setting, because a receiver's curve is adopted by the sender and the ports
// only matter to a peer that dials this side directly.
const (
	crocBasePort            = 9009
	crocTransfers           = 4
	crocCurve               = "p256"
	DefaultMulticastAddress = "239.255.255.250"
)

// relayPorts is the send command's port list (cli.go send): the base port,
// then one more per transfer. The sender's local relay listens on them.
func relayPorts() []string {
	ports := make([]string, crocTransfers+1)
	for i := range ports {
		ports[i] = strconv.Itoa(crocBasePort + i)
	}
	return ports
}

func invalidSetting(format string, args ...any) error {
	return &codedError{codeInvalidSetting, fmt.Errorf(format, args...)}
}

// The names ValidateSetting accepts. Each is the Options field of the same
// name, except SettingStoreServer, which is StoreOptions.Server.
const (
	SettingSocks5Proxy      = "Socks5Proxy"
	SettingHTTPProxy        = "HTTPProxy"
	SettingThrottleUpload   = "ThrottleUpload"
	SettingMulticastAddress = "MulticastAddress"
	SettingPeerIP           = "PeerIP"
	SettingStoreServer      = "StoreServer"
)

// settingChecks is the one place a setting's check is named. A transfer start
// runs the five network checks through validateNetworkOptions, and
// ValidateSetting runs any of them for a settings form, so the two cannot
// disagree.
var settingChecks = map[string]func(value string) error{
	SettingSocks5Proxy:      validateSocks5Proxy,
	SettingHTTPProxy:        validateHTTPProxy,
	SettingThrottleUpload:   validateThrottle,
	SettingMulticastAddress: validateMulticastAddress,
	SettingPeerIP:           validatePeerIP,
	SettingStoreServer:      validateStoreServer,
}

// ValidateSetting reports whether the engine accepts value for the setting
// named field (one of the Setting constants), by running the check a transfer
// start runs. It takes no lock and touches no transfer state, so it is safe at
// any time, including during a transfer.
//
// Blank is valid for every setting except SettingStoreServer, which needs an
// origin. A rejected value fails with code "invalidSetting", an unknown field
// with code "other". Proxy errors never quote the value: it can carry
// credentials. Exported across gobind like StartSend, so it recovers a panic
// into an error.
func ValidateSetting(field, value string) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = startError(fmt.Errorf("croc panic: %v", r))
		}
	}()
	check, ok := settingChecks[field]
	if !ok {
		return startError(fmt.Errorf("unknown setting %q", field))
	}
	return startError(check(value))
}

// validateNetworkOptions checks the Advanced options croc would otherwise take
// as given and fail on late, or silently ignore. Proxy errors never quote the
// value: it can carry credentials.
func validateNetworkOptions(o *Options) error {
	for _, c := range []struct{ field, value string }{
		{SettingSocks5Proxy, o.Socks5Proxy},
		{SettingHTTPProxy, o.HTTPProxy},
		{SettingThrottleUpload, o.ThrottleUpload},
		{SettingMulticastAddress, o.MulticastAddress},
		{SettingPeerIP, o.PeerIP},
	} {
		if err := settingChecks[c.field](c.value); err != nil {
			return err
		}
	}
	return nil
}

// validateStoreServer is validateStoreOrigin, the check StartStoreSend runs,
// with the invalidSetting code ValidateSetting reports. StartStoreSend keeps the
// plain error, so a refused server keeps its code "other" there.
func validateStoreServer(value string) error {
	if err := validateStoreOrigin(value); err != nil {
		return &codedError{codeInvalidSetting, err}
	}
	return nil
}

func validateMulticastAddress(value string) error {
	m := strings.TrimSpace(value)
	if m == "" {
		return nil
	}
	ip := net.ParseIP(m)
	if ip == nil || ip.To4() == nil || !ip.IsMulticast() {
		return invalidSetting("multicast address %q is not an IPv4 multicast address", m)
	}
	return nil
}

func validatePeerIP(value string) error {
	p := strings.TrimSpace(value)
	if p == "" {
		return nil
	}
	host, port, err := net.SplitHostPort(p)
	if err != nil || net.ParseIP(host) == nil {
		return invalidSetting("sender IP %q is not an IP address with a port", p)
	}
	if n, err := strconv.Atoi(port); err != nil || n < 1 || n > 65535 {
		return invalidSetting("sender IP %q has no valid port", p)
	}
	return nil
}

// The two proxy settings accept what croc's dialer accepts: host:port, or a URL
// with one of the given schemes (croc adds the default scheme to a bare
// host:port). The URL forms are also what storeClient dials through.
func socks5ProxyURL(value string) (*url.URL, error) {
	return proxyURL(value, "socks5", "socks5", "socks5h")
}

func httpProxyURL(value string) (*url.URL, error) {
	return proxyURL(value, "http", "http", "https")
}

func validateSocks5Proxy(value string) error {
	_, err := socks5ProxyURL(value)
	return err
}

func validateHTTPProxy(value string) error {
	_, err := httpProxyURL(value)
	return err
}

func proxyURL(value, defaultScheme string, schemes ...string) (*url.URL, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil, nil
	}
	if !strings.Contains(value, "://") {
		value = defaultScheme + "://" + value
	}
	u, err := url.Parse(value)
	// net/url refuses a host with an unbracketed colon ("::1", "host:1080:2")
	// for http and https only, and allows a non-ASCII space in any host; both
	// would reach a dial that cannot work.
	if err != nil || u.Hostname() == "" || (strings.Contains(u.Hostname(), ":") && !strings.HasPrefix(u.Host, "[")) ||
		strings.IndexFunc(u.Hostname(), unicode.IsSpace) >= 0 {
		return nil, invalidSetting("%s proxy is not host:port or a proxy URL", defaultScheme)
	}
	if port, err := strconv.Atoi(u.Port()); err != nil || port < 1 || port > 65535 {
		return nil, invalidSetting("%s proxy has no valid port", defaultScheme)
	}
	for _, s := range schemes {
		if u.Scheme == s {
			return u, nil
		}
	}
	return nil, invalidSetting("%s proxy scheme must be one of %s", defaultScheme, strings.Join(schemes, ", "))
}

// validateThrottle accepts croc's upload limit format: bytes per second,
// optionally followed by k, m or g. croc panics on anything else and on zero,
// and silently ignores a one-character value, so those are refused here.
func validateThrottle(value string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	digits := value
	if strings.ContainsRune("kKmMgG", rune(value[len(value)-1])) {
		digits = value[:len(value)-1]
	}
	n, err := strconv.ParseInt(digits, 10, 64)
	if len(value) < 2 || err != nil || n < 1 || strings.ContainsAny(digits, "+-") {
		return invalidSetting("upload limit %q is not a speed such as 500k", value)
	}
	return nil
}

// setNetworkGlobals points croc's process-wide proxy settings at o and returns
// the function that puts the previous values back. croc reads these at dial
// time, so they are only written while activeMu is held, and the restore runs
// before the lock is released.
func setNetworkGlobals(o *Options) (restore func()) {
	socks5, httpProxy := comm.Socks5Proxy, comm.HttpProxy
	comm.Socks5Proxy = strings.TrimSpace(o.Socks5Proxy)
	comm.HttpProxy = strings.TrimSpace(o.HTTPProxy)
	return func() {
		comm.Socks5Proxy, comm.HttpProxy = socks5, httpProxy
	}
}

// storeClient returns a storeclient.Client that never reads croc's proxy
// globals: RevokeStored runs outside activeMu, where reading them would race a
// transfer that sets them. The HTTP client mirrors storeclient's own default
// (SOCKS5 before HTTP, no redirects), with the proxies from o.
func storeClient(o *StoreOptions) (*storeclient.Client, error) {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	if o != nil {
		socks5, err := socks5ProxyURL(o.Socks5Proxy)
		if err != nil {
			return nil, err
		}
		httpProxy, err := httpProxyURL(o.HTTPProxy)
		if err != nil {
			return nil, err
		}
		if socks5 != nil {
			transport.Proxy = http.ProxyURL(socks5)
		} else if httpProxy != nil {
			transport.Proxy = http.ProxyURL(httpProxy)
		}
	}
	return &storeclient.Client{HTTP: &http.Client{
		Transport: transport,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return errors.New("stored-transfer redirects are not allowed")
		},
	}}, nil
}
