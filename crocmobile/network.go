package crocmobile

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/schollz/croc/v11/src/comm"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/storeclient"
)

// croc CLI defaults for the Advanced options (cli.go: --port, --transfers,
// --multicast).
const (
	DefaultBasePort         = 9009
	DefaultTransfers        = 4
	DefaultMulticastAddress = "239.255.255.250"
)

// relayPorts is the send command's port list (cli.go send): the base port,
// then one more per transfer. The sender's local relay listens on them.
func relayPorts(o *Options) ([]string, error) {
	base, n := o.BasePort, o.Transfers
	if base == 0 {
		base = DefaultBasePort
	}
	if n == 0 {
		n = DefaultTransfers
	}
	if base < 1 || n < 1 || base > 65535-n {
		return nil, invalidSetting("ports %d to %d are out of range", base, base+n)
	}
	ports := make([]string, n+1)
	for i := range ports {
		ports[i] = strconv.Itoa(base + i)
	}
	return ports, nil
}

func invalidSetting(format string, args ...any) error {
	return &codedError{codeInvalidSetting, fmt.Errorf(format, args...)}
}

// validateNetworkOptions checks the Advanced options croc would otherwise take
// as given and fail on late, or silently ignore. Proxy errors never quote the
// value: it can carry credentials.
func validateNetworkOptions(o *Options) error {
	if err := validateProxy(o.Socks5Proxy, "socks5", "socks5", "socks5h"); err != nil {
		return err
	}
	if err := validateProxy(o.HTTPProxy, "http", "http", "https"); err != nil {
		return err
	}
	if err := validateThrottle(o.ThrottleUpload); err != nil {
		return err
	}
	if m := strings.TrimSpace(o.MulticastAddress); m != "" {
		ip := net.ParseIP(m)
		if ip == nil || ip.To4() == nil || !ip.IsMulticast() {
			return invalidSetting("multicast address %q is not an IPv4 multicast address", m)
		}
	}
	if p := strings.TrimSpace(o.PeerIP); p != "" {
		host, port, err := net.SplitHostPort(p)
		if err != nil || net.ParseIP(host) == nil {
			return invalidSetting("sender IP %q is not an IP address with a port", p)
		}
		if n, err := strconv.Atoi(port); err != nil || n < 1 || n > 65535 {
			return invalidSetting("sender IP %q has no valid port", p)
		}
	}
	return nil
}

// validateProxy accepts what croc's dialer accepts: host:port, or a URL with
// one of the given schemes (croc adds defaultScheme to a bare host:port).
func validateProxy(value, defaultScheme string, schemes ...string) error {
	_, err := proxyURL(value, defaultScheme, schemes...)
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
	if err != nil || u.Hostname() == "" {
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

// setNetworkGlobals points croc's process-wide proxy and DNS settings at o and
// returns the function that puts the previous values back. croc reads these
// at dial time, so they are only written while activeMu is held, and the
// restore runs before the lock is released.
func setNetworkGlobals(o *Options) (restore func()) {
	socks5, httpProxy, internalDNS := comm.Socks5Proxy, comm.HttpProxy, models.INTERNAL_DNS
	comm.Socks5Proxy = strings.TrimSpace(o.Socks5Proxy)
	comm.HttpProxy = strings.TrimSpace(o.HTTPProxy)
	models.INTERNAL_DNS = o.InternalDNS
	return func() {
		comm.Socks5Proxy, comm.HttpProxy, models.INTERNAL_DNS = socks5, httpProxy, internalDNS
	}
}

// storeClient returns a storeclient.Client that never reads croc's proxy
// globals: RevokeStored runs outside activeMu, where reading them would race a
// transfer that sets them. The HTTP client mirrors storeclient's own default
// (SOCKS5 before HTTP, no redirects), with the proxies from o.
func storeClient(o *StoreOptions) (*storeclient.Client, error) {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	if o != nil {
		socks5, err := proxyURL(o.Socks5Proxy, "socks5", "socks5", "socks5h")
		if err != nil {
			return nil, err
		}
		httpProxy, err := proxyURL(o.HTTPProxy, "http", "http", "https")
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
