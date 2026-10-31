package crocmobile

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net"
	"net/netip"
	"strings"
	"time"

	"github.com/schollz/croc/v11/src/comm"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/tcp"
)

// relayCheckTimeout bounds one CheckRelay: name lookup, connect and handshake.
const relayCheckTimeout = 5 * time.Second

// codeNoAddress is CheckRelay's own result code: the relay's name has no
// address of the family asked for. It is not a transfer failure code.
const codeNoAddress = "noAddress"

type relayCheck struct {
	Family    string  `json:"family"`
	IP        string  `json:"ip,omitempty"`
	Reachable bool    `json:"reachable"`
	LatencyMs float64 `json:"latencyMs,omitempty"`
	// PasswordOK is absent when the relay could not be reached or answered
	// something other than croc's handshake.
	PasswordOK *bool  `json:"passwordOk,omitempty"`
	Code       string `json:"code,omitempty"`
}

// CheckRelay probes the relay at address (host:port) over one address family,
// "4" or "6", and returns a JSON object: family, ip, reachable, latencyMs (the
// TCP connect time), passwordOk, and code, which is empty when the relay is
// reachable and accepts the password, else "noAddress", "badPassword",
// "relayUnreachable", "invalidSetting" or "other". A blank password means
// croc's default.
//
// The password is checked with croc's own relay handshake (the one a transfer
// opens with), joined to a throwaway room that no peer ever enters, so no
// transfer starts. The check dials directly, never through the proxy settings,
// and takes no transfer lock, so it runs during a transfer. It never reports or
// logs the password. Exported across gobind like StartSend, so it recovers a
// panic into an "other" result.
func CheckRelay(address, password, family string) (result string) {
	res := relayCheck{Family: family}
	defer func() {
		if r := recover(); r != nil {
			res = relayCheck{Family: family, Code: codeOther}
		}
		b, _ := json.Marshal(res)
		result = string(b)
	}()
	res = checkRelay(address, password, family)
	return
}

func checkRelay(address, password, family string) relayCheck {
	res := relayCheck{Family: family}
	host, port, err := net.SplitHostPort(strings.TrimSpace(address))
	if err != nil || host == "" || (family != "4" && family != "6") {
		res.Code = codeInvalidSetting
		return res
	}
	password = strings.TrimSpace(password)
	if password == "" {
		password = models.DEFAULT_PASSPHRASE
	}
	ctx, cancel := context.WithTimeout(context.Background(), relayCheckTimeout)
	defer cancel()

	var ips []netip.Addr
	if literal, err := netip.ParseAddr(host); err == nil {
		literal = literal.Unmap()
		if literal.Is4() == (family == "4") {
			ips = []netip.Addr{literal}
		}
	} else if ips, err = net.DefaultResolver.LookupNetIP(ctx, "ip"+family, host); err != nil {
		var dnsErr *net.DNSError
		if errors.As(err, &dnsErr) && dnsErr.IsNotFound {
			res.Code = codeNoAddress
		} else {
			res.Code = codeRelayUnreachable
		}
		return res
	}
	if len(ips) == 0 {
		res.Code = codeNoAddress
		return res
	}
	res.IP = ips[0].String()

	started := time.Now()
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp"+family, net.JoinHostPort(res.IP, port))
	if err != nil {
		res.Code = codeRelayUnreachable
		return res
	}
	defer conn.Close()
	res.Reachable = true
	res.LatencyMs = float64(time.Since(started).Microseconds()) / 1000

	deadline, _ := ctx.Deadline()
	if err := conn.SetDeadline(deadline); err != nil {
		res.Code = codeOther
		return res
	}
	var room [8]byte
	if _, err := rand.Read(room[:]); err != nil {
		res.Code = codeOther
		return res
	}
	_, _, _, err = tcp.HandshakeTCPServerCapability(comm.New(conn), password, "croc-check-"+hex.EncodeToString(room[:]))
	ok := err == nil
	res.PasswordOK = &ok
	if err != nil {
		if code := classify(err); code == codeBadPassword {
			res.Code = code
		} else {
			// Not croc's answer (a timeout, a reset, another protocol), so the
			// password is neither accepted nor refused.
			res.PasswordOK = nil
			res.Code = codeOther
		}
	}
	return res
}
