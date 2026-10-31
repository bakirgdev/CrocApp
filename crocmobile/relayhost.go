package crocmobile

import (
	"context"
	"errors"
	"fmt"
	"net"
	"runtime/debug"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/tcp"
)

// RelayPortCount is how many ports a hosted relay uses, counted from its base
// port: the croc CLI's `relay` default (cli.go relay), --transfers 4, the first
// the control port that announces the rest as its banner.
const RelayPortCount = 4

// stopWait bounds how long Stop waits for the listeners to close. They close
// as soon as the context is cancelled, so this only guards a stuck connection.
const stopWait = 3 * time.Second

// RelayDelegate learns that a running relay stopped on its own. It is not
// called after Stop.
type RelayDelegate interface {
	// OnRelayStopped delivers the failure payload ({"code","message"}).
	OnRelayStopped(failureJSON string)
}

// RelayHost is a croc relay running in this process, serving the port range it
// was started with. It shares no state with transfers (no activeMu, no stdio,
// no proxy globals), so it runs alongside one.
type RelayHost struct {
	cancel context.CancelFunc
	done   chan struct{}
	ports  []string
}

// StartRelay serves croc's relay protocol on port and the next three ports of
// host (empty host: every interface), as `croc relay --port` does. A blank
// password means croc's default, which anyone can use. It fails at once, with
// no listener left open, when a port cannot be bound: code "portInUse" for a
// taken one, "invalidSetting" for a port range outside 1 to 65535. d may be nil.
//
// Exported across gobind like StartSend, so it recovers a panic into an error.
func StartRelay(host string, port int, password string, d RelayDelegate) (h *RelayHost, err error) {
	defer func() {
		if r := recover(); r != nil {
			h, err = nil, startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	if port < 1 || port+RelayPortCount-1 > 65535 {
		return nil, startError(invalidSetting("relay port must be 1 to %d", 65535-RelayPortCount+1))
	}
	password = strings.TrimSpace(password)
	if password == "" {
		password = models.DEFAULT_PASSPHRASE
	}
	host = strings.TrimSpace(host)

	ports := make([]string, RelayPortCount)
	listeners := make([]net.Listener, 0, RelayPortCount)
	for i := range ports {
		ports[i] = strconv.Itoa(port + i)
		l, err := net.Listen("tcp", net.JoinHostPort(host, ports[i]))
		if err != nil {
			for _, open := range listeners {
				open.Close()
			}
			return nil, startError(listenError(err))
		}
		listeners = append(listeners, l)
	}
	return serveRelay(listeners, ports, password, d)
}

// serveRelay runs the relay on listeners it takes ownership of. Split from
// StartRelay so a test can hand it listeners that fail.
func serveRelay(listeners []net.Listener, ports []string, password string, d RelayDelegate) (*RelayHost, error) {
	capabilities, err := tcp.NewRelayCapabilitySet(len(ports) - 1)
	if err != nil {
		for _, open := range listeners {
			open.Close()
		}
		return nil, startError(err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	h := &RelayHost{cancel: cancel, done: make(chan struct{}), ports: ports}
	var wg sync.WaitGroup
	var stopped sync.Once
	for i, l := range listeners {
		banner := ""
		if i == 0 {
			banner = strings.Join(ports[1:], ",")
		}
		wg.Go(func() {
			err := tcp.RunWithListener(l, password,
				tcp.WithBanner(banner),
				// The relay logs each client's address at debug.
				tcp.WithLogLevel("warn"),
				tcp.WithFastAdmission(capabilities),
				tcp.WithCtx(ctx),
			)
			if err == nil || ctx.Err() != nil {
				return
			}
			// One dead port leaves a relay that fails some transfers, so the
			// whole relay stops and says why.
			stopped.Do(func() {
				cancel()
				if d != nil {
					go d.OnRelayStopped(errorJSON(err))
				}
			})
		})
	}
	go func() {
		wg.Wait()
		close(h.done)
	}()
	return h, nil
}

// Ports returns the relay's ports, comma-separated, control port first.
func (h *RelayHost) Ports() string { return strings.Join(h.ports, ",") }

// Stop closes the relay's listeners and connections and waits briefly for
// them. Safe to call more than once, and after the relay stopped itself.
func (h *RelayHost) Stop() {
	defer func() { recover() }() //nolint:errcheck // gobind: a panic here must never cross into the host app
	h.cancel()
	select {
	case <-h.done:
	case <-time.After(stopWait):
	}
}

// listenError gives a taken port its own failure code.
func listenError(err error) error {
	if errors.Is(err, syscall.EADDRINUSE) {
		return &codedError{codePortInUse, err}
	}
	return err
}
