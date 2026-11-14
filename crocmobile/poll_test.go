// shortcut: excluded under -race because poll() reads croc.Client fields croc writes (issue #184); remove the constraint when croc ships a progress callback.

//go:build !race

package crocmobile

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// A full receive through session.poll, against croc's own relay package and a
// plain croc client, so the path that runs poll against a live croc.Client does
// not depend on relayhost.go. Both peers cannot be app transfers: crocmobile
// runs one at a time per process.
func TestReceiveThroughPollOverCrocRelay(t *testing.T) {
	relay := startTestRelay(t)
	sendErr := make(chan error, 1)
	go func() {
		sendErr <- runClient(t, timeout(t, 30*time.Second), testClientOptions(true, relay, testRelayPassword, "poll-receive-code"))
	}()
	time.Sleep(500 * time.Millisecond) // sender first (crocmobile-bridge.md, "Start order: sender first")

	out := t.TempDir()
	o := NewOptionsDefault()
	o.RelayAddress, o.RelayPassword, o.DisableLocal, o.OutDir, o.AutoAccept = relay, testRelayPassword, true, out, true
	rec := newStoreRecorder()
	recv, err := StartReceive("poll-receive-code", o, rec)
	if err != nil {
		t.Fatal(err)
	}
	defer recv.Cancel()
	rec.wait(t)
	if rec.errMsg != "" || rec.done == "" {
		t.Fatalf("receive: error %q, done %q", rec.errMsg, rec.done)
	}
	if !strings.Contains(rec.fileList, "f.txt") {
		t.Fatalf("file list %q does not name f.txt", rec.fileList)
	}
	if err := <-sendErr; err != nil {
		t.Fatalf("send: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(out, "f.txt")); err != nil || string(b) != "hi" {
		t.Fatalf("received %q, %v", b, err)
	}
}
