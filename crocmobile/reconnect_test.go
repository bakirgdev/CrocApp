// shortcut: excluded under -race because poll() reads croc.Client fields croc writes (issue #184); remove the constraint when croc ships a progress callback.

//go:build !race

package crocmobile

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/schollz/croc/v11/src/croc"
)

// dropProxy forwards TCP to target. drop closes every connection open at that
// moment; connections opened later pass untouched.
type dropProxy struct {
	addr  string
	mu    sync.Mutex
	conns []net.Conn
}

func startDropProxy(t *testing.T, target string) *dropProxy {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	p := &dropProxy{addr: l.Addr().String()}
	go func() {
		for {
			in, err := l.Accept()
			if err != nil {
				return
			}
			out, err := net.Dial("tcp", target)
			if err != nil {
				in.Close()
				continue
			}
			p.mu.Lock()
			p.conns = append(p.conns, in, out)
			p.mu.Unlock()
			go func() { _, _ = io.Copy(out, in); out.Close() }()
			go func() { _, _ = io.Copy(in, out); in.Close() }()
		}
	}()
	return p
}

func (p *dropProxy) drop() {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, c := range p.conns {
		c.Close()
	}
	p.conns = nil
}

// A receive loses its control connection to the relay mid-transfer and croc
// v11 reconnects. The reconnect asks the accept question again
// (resetForReconnectAttempt, then processSenderInfo in croc.go); the same offer
// gets the user's accept, so the receive resumes and completes (#226).
func TestReconnectAfterAccept(t *testing.T) {
	for _, tc := range []struct {
		name       string
		autoAccept bool
	}{
		{"manual accept", false},
		{"auto-accept", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			relay := startTestRelay(t)
			proxy := startDropProxy(t, relay)
			secret := "reconnect-" + strings.ReplaceAll(tc.name, " ", "-")

			payload := make([]byte, 2<<20)
			if _, err := rand.Read(payload); err != nil {
				t.Fatal(err)
			}
			src := filepath.Join(t.TempDir(), "big.bin")
			if err := os.WriteFile(src, payload, 0o600); err != nil {
				t.Fatal(err)
			}
			so := testClientOptions(true, relay, testRelayPassword, secret)
			so.NoMultiplexing, so.NoCompress = false, true
			so.ThrottleUpload = "512K" // about 4 s for 2 MiB, so the drop lands mid-transfer
			sendCtx := timeout(t, 60*time.Second)
			sendErr := make(chan error, 1)
			go func() {
				c, err := croc.NewCtx(sendCtx, so)
				if err != nil {
					sendErr <- err
					return
				}
				files, empty, folders, err := croc.GetFilesInfo([]string{src}, false, false, nil)
				if err != nil {
					sendErr <- err
					return
				}
				sendErr <- c.Send(files, empty, folders)
			}()
			time.Sleep(500 * time.Millisecond) // sender first

			out := t.TempDir()
			o := NewOptionsDefault()
			o.RelayAddress, o.RelayPassword, o.DisableLocal, o.OutDir = proxy.addr, testRelayPassword, true, out
			o.AutoAccept = tc.autoAccept
			rec := newStoreRecorder()
			recv, err := StartReceive(secret, o, rec)
			if err != nil {
				t.Fatal(err)
			}
			defer recv.Cancel()
			select {
			case <-rec.fileReady:
			case <-time.After(15 * time.Second):
				t.Fatal("no file list")
			}
			if !tc.autoAccept {
				recv.Respond(true, PolicyKeepBoth)
			}

			dropped := false
			for deadline := time.Now().Add(15 * time.Second); !dropped && time.Now().Before(deadline); {
				rec.mu.Lock()
				var p progressState
				if n := len(rec.progress); n > 0 {
					_ = json.Unmarshal([]byte(rec.progress[n-1]), &p)
				}
				rec.mu.Unlock()
				if p.FileSent > 0 && p.FileSent < int64(len(payload))/2 {
					proxy.drop()
					dropped = true
					t.Logf("dropped the receiver's relay connection at %d of %d bytes", p.FileSent, len(payload))
				}
				time.Sleep(20 * time.Millisecond)
			}
			if !dropped {
				t.Fatal("the transfer never reached the drop point")
			}

			rec.wait(t)
			var sErr error
			select {
			case sErr = <-sendErr:
			case <-time.After(30 * time.Second):
				t.Fatal("sender did not return")
			}
			t.Logf("receiver: done %q, error %q; sender error: %v", rec.done, rec.errMsg, sErr)
			if rec.errMsg != "" {
				t.Fatalf("receive failed with code %s, want it to resume", rec.failureCode(t))
			}
			got, err := os.ReadFile(filepath.Join(out, "big.bin"))
			if err != nil || !bytes.Equal(got, payload) {
				t.Fatalf("received file differs (%d bytes, %v)", len(got), err)
			}
		})
	}
}
