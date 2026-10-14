package crocmobile

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/schollz/croc/v11/src/store"
	"github.com/schollz/croc/v11/src/storeclient"
	"github.com/schollz/croc/v11/src/storecrypto"
)

// storeRecorder collects a stored transfer's delegate calls. wait returns once
// the terminal one (OnDone or OnError) has arrived.
type storeRecorder struct {
	mu        sync.Mutex
	fileList  string
	receipt   string
	done      string
	errMsg    string
	progress  []string
	finished  chan struct{}
	fileReady chan struct{}
	onceFile  sync.Once
	onceEnd   sync.Once
}

func newStoreRecorder() *storeRecorder {
	return &storeRecorder{finished: make(chan struct{}), fileReady: make(chan struct{})}
}

func (r *storeRecorder) OnCodeReady(string) {}
func (r *storeRecorder) OnConnected()       {}
func (r *storeRecorder) OnText(string)      {}
func (r *storeRecorder) OnFileList(j string) {
	r.mu.Lock()
	r.fileList = j
	r.mu.Unlock()
	r.onceFile.Do(func() { close(r.fileReady) })
}
func (r *storeRecorder) OnProgress(j string) {
	r.mu.Lock()
	r.progress = append(r.progress, j)
	r.mu.Unlock()
}
func (r *storeRecorder) OnStored(j string) {
	r.mu.Lock()
	r.receipt = j
	r.mu.Unlock()
}
func (r *storeRecorder) OnDone(j string) {
	r.mu.Lock()
	r.done = j
	r.mu.Unlock()
	r.onceEnd.Do(func() { close(r.finished) })
}
func (r *storeRecorder) OnError(m string) {
	r.mu.Lock()
	r.errMsg = m
	r.mu.Unlock()
	r.onceEnd.Do(func() { close(r.finished) })
}

func (r *storeRecorder) wait(t *testing.T) {
	t.Helper()
	select {
	case <-r.finished:
	case <-time.After(30 * time.Second):
		t.Fatal("stored transfer did not finish")
	}
	// run releases activeMu after the terminal call; wait for it so the next
	// start in the same test cannot see "another transfer is active".
	for i := 0; i < 200 && !activeMu.TryLock(); i++ {
		time.Sleep(10 * time.Millisecond)
	}
	activeMu.Unlock()
}

func (r *storeRecorder) failureCode(t *testing.T) string {
	t.Helper()
	var f failure
	if err := json.Unmarshal([]byte(r.errMsg), &f); err != nil {
		t.Fatalf("OnError payload %q is not JSON: %v", r.errMsg, err)
	}
	return f.Code
}

func startTestStore(t *testing.T, cfg store.Config) string {
	t.Helper()
	cfg.Root = t.TempDir()
	cfg.MaxTransferBytes = 8 << 20
	cfg.MaxTotalBytes = 32 << 20
	cfg.MinFreeBytes = 1
	cfg.CreatePerHour = 100
	cfg.MaxActiveUploads = 10
	cfg.DisableRootLock = true
	if cfg.MaxDownloads == 0 {
		cfg.MaxDownloads = 10
	}
	svc, err := store.New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(svc)
	t.Cleanup(func() {
		srv.Close()
		_ = svc.Close()
	})
	return srv.URL
}

func writeFiles(t *testing.T, dir string, files map[string]string) []string {
	t.Helper()
	var paths []string
	for name, body := range files {
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		paths = append(paths, p)
	}
	return paths
}

func storeSend(t *testing.T, server string, o StoreOptions, paths []string) (*storeRecorder, storedReceipt) {
	t.Helper()
	o.Server = server
	rec := newStoreRecorder()
	if _, err := StartStoreSend(strings.Join(paths, "\n"), &o, rec); err != nil {
		t.Fatalf("StartStoreSend: %v", err)
	}
	rec.wait(t)
	var r storedReceipt
	if rec.errMsg == "" {
		if err := json.Unmarshal([]byte(rec.receipt), &r); err != nil {
			t.Fatalf("receipt %q: %v", rec.receipt, err)
		}
	}
	return rec, r
}

func storeReceive(t *testing.T, link, out string, accept bool, policy string) *storeRecorder {
	t.Helper()
	rec := newStoreRecorder()
	tr, err := StartStoreReceive(link, out, rec)
	if err != nil {
		t.Fatalf("StartStoreReceive: %v", err)
	}
	select {
	case <-rec.fileReady:
	case <-rec.finished:
		rec.wait(t)
		return rec
	case <-time.After(30 * time.Second):
		t.Fatal("no file list")
	}
	tr.Respond(accept, policy)
	rec.wait(t)
	return rec
}

func readFile(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func TestStoreSendReceiveRevoke(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	paths := writeFiles(t, src, map[string]string{"a.txt": "alpha", "b.txt": "bravo"})

	rec, receipt := storeSend(t, server, StoreOptions{Downloads: 2, LifetimeSeconds: 3600}, paths)
	if rec.errMsg != "" {
		t.Fatalf("send failed: %s", rec.errMsg)
	}
	if receipt.Origin != server || receipt.ID == "" || receipt.UploadToken == "" || receipt.Downloads != 2 {
		t.Fatalf("receipt = %+v", receipt)
	}
	if !strings.HasPrefix(receipt.Link, server+"/s/"+receipt.ID+"#v1.") {
		t.Fatalf("link = %q", receipt.Link)
	}
	exp, err := time.Parse(time.RFC3339, receipt.ExpiresAt)
	if err != nil || time.Until(exp) < 50*time.Minute || time.Until(exp) > 70*time.Minute {
		t.Fatalf("expiresAt = %q (%v); want about one hour out", receipt.ExpiresAt, err)
	}
	var sum map[string]any
	if err := json.Unmarshal([]byte(rec.done), &sum); err != nil || sum["success"] != true || sum["files"] != float64(2) || sum["totalSize"] != float64(10) {
		t.Fatalf("done = %q (%v)", rec.done, err)
	}
	if len(rec.progress) == 0 {
		t.Fatal("no OnProgress events")
	}

	out := t.TempDir()
	got := storeReceive(t, receipt.Link, out, true, PolicyKeepBoth)
	if got.errMsg != "" {
		t.Fatalf("receive failed: %s", got.errMsg)
	}
	if readFile(t, filepath.Join(out, "a.txt")) != "alpha" || readFile(t, filepath.Join(out, "b.txt")) != "bravo" {
		t.Fatal("received content differs")
	}
	var list struct {
		Files []fileEntry `json:"files"`
		Total int64       `json:"totalSize"`
	}
	if err := json.Unmarshal([]byte(got.fileList), &list); err != nil || len(list.Files) != 2 || list.Total != 10 {
		t.Fatalf("file list = %q (%v)", got.fileList, err)
	}

	if err := RevokeStored(receipt.Origin, receipt.ID, receipt.UploadToken); err != nil {
		t.Fatalf("RevokeStored: %v", err)
	}
	gone := storeReceive(t, receipt.Link, t.TempDir(), true, PolicyKeepBoth)
	if c := gone.failureCode(t); c != codeStoreExpired {
		t.Fatalf("receive after revoke: code %q (%s), want %q", c, gone.errMsg, codeStoreExpired)
	}
}

func TestStoreRevokeTreatsMissingAsSuccess(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	_, receipt := storeSend(t, server, StoreOptions{}, writeFiles(t, src, map[string]string{"a.txt": "x"}))
	if err := RevokeStored(receipt.Origin, receipt.ID, receipt.UploadToken); err != nil {
		t.Fatal(err)
	}
	if err := RevokeStored(receipt.Origin, receipt.ID, receipt.UploadToken); err != nil {
		t.Fatalf("second revoke: %v", err)
	}
}

func TestStoreRevokeFailureIsCoded(t *testing.T) {
	err := RevokeStored("http://127.0.0.1:1", strings.Repeat("A", 22), "token")
	if err == nil {
		t.Fatal("revoke against a closed port succeeded")
	}
	var f failure
	if json.Unmarshal([]byte(err.Error()), &f) != nil || f.Code == "" {
		t.Fatalf("error %q is not a failure payload", err)
	}
}

func TestStoreReceiveKeepBothAndReplace(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	_, receipt := storeSend(t, server, StoreOptions{Downloads: 5},
		writeFiles(t, src, map[string]string{"a.txt": "new-a", "a (1).txt": "new-a1", "b.txt": "new-b"}))

	out := t.TempDir()
	writeFiles(t, out, map[string]string{"a.txt": "old-a"})

	if rec := storeReceive(t, receipt.Link, out, true, PolicyKeepBoth); rec.errMsg != "" {
		t.Fatalf("keep both: %s", rec.errMsg)
	}
	if got := readFile(t, filepath.Join(out, "a.txt")); got != "old-a" {
		t.Fatalf("a.txt = %q; Keep Both must leave it alone", got)
	}
	// "a (1).txt" is also a member, so the colliding "a.txt" must skip to (2).
	if got := readFile(t, filepath.Join(out, "a (1).txt")); got != "new-a1" {
		t.Fatalf("a (1).txt = %q; the member of that name must keep it", got)
	}
	if got := readFile(t, filepath.Join(out, "a (2).txt")); got != "new-a" {
		t.Fatalf("a (2).txt = %q, want the renamed copy", got)
	}
	if got := readFile(t, filepath.Join(out, "b.txt")); got != "new-b" {
		t.Fatalf("b.txt = %q", got)
	}

	out2 := t.TempDir()
	writeFiles(t, out2, map[string]string{"a.txt": "old-a", "b.txt": "old-b"})
	if rec := storeReceive(t, receipt.Link, out2, true, PolicyReplace); rec.errMsg != "" {
		t.Fatalf("replace: %s", rec.errMsg)
	}
	if readFile(t, filepath.Join(out2, "a.txt")) != "new-a" || readFile(t, filepath.Join(out2, "b.txt")) != "new-b" {
		t.Fatal("Replace did not overwrite")
	}
	if _, err := os.Stat(filepath.Join(out2, "a (2).txt")); !os.IsNotExist(err) {
		t.Fatal("Replace left a renamed copy")
	}
}

func TestStoreReceiveDeclineLeavesTransferUnclaimed(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	_, receipt := storeSend(t, server, StoreOptions{}, writeFiles(t, src, map[string]string{"a.txt": "x"}))

	out := t.TempDir()
	rec := storeReceive(t, receipt.Link, out, false, PolicyKeepBoth)
	if c := rec.failureCode(t); c != codeRefused {
		t.Fatalf("code = %q, want %q", c, codeRefused)
	}
	if entries, _ := os.ReadDir(out); len(entries) != 0 {
		t.Fatalf("decline wrote %d entries", len(entries))
	}
	// Unclaimed means the one download is still there.
	if rec := storeReceive(t, receipt.Link, out, true, PolicyKeepBoth); rec.errMsg != "" {
		t.Fatalf("receive after decline: %s", rec.errMsg)
	}
}

func TestStoreReceiveCancelWhileWaiting(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	_, receipt := storeSend(t, server, StoreOptions{}, writeFiles(t, src, map[string]string{"a.txt": "x"}))

	rec := newStoreRecorder()
	tr, err := StartStoreReceive(receipt.Link, t.TempDir(), rec)
	if err != nil {
		t.Fatal(err)
	}
	<-rec.fileReady
	tr.Cancel()
	rec.wait(t)
	if c := rec.failureCode(t); c != codeCancelled {
		t.Fatalf("code = %q, want %q", c, codeCancelled)
	}
}

func TestStoreSendCancel(t *testing.T) {
	server := startTestStore(t, store.Config{})
	// 7 MiB is two chunks, so there is an upload to interrupt.
	src := t.TempDir()
	big := filepath.Join(src, "big.bin")
	if err := os.WriteFile(big, bytes.Repeat([]byte{7}, 7<<20), 0o644); err != nil {
		t.Fatal(err)
	}
	rec := newStoreRecorder()
	tr, err := StartStoreSend(big, &StoreOptions{Server: server}, rec)
	if err != nil {
		t.Fatal(err)
	}
	tr.Cancel()
	rec.wait(t)
	if rec.receipt != "" {
		t.Fatal("cancelled upload produced a receipt")
	}
	if c := rec.failureCode(t); c != codeCancelled {
		t.Fatalf("code = %q (%s), want %q", c, rec.errMsg, codeCancelled)
	}
}

func TestStoreSendLimitsFailBeforeUpload(t *testing.T) {
	src := t.TempDir()
	one := writeFiles(t, src, map[string]string{"a.txt": "x"})[0]
	cases := []struct {
		name  string
		paths string
		opts  StoreOptions
		code  string
	}{
		{"too many files", strings.Repeat(one+"\n", storeMaxFiles+1), StoreOptions{Server: "https://example.com"}, codeStoreLimit},
		{"downloads over 100", one, StoreOptions{Server: "https://example.com", Downloads: 101}, codeStoreLimit},
		{"negative downloads", one, StoreOptions{Server: "https://example.com", Downloads: -1}, codeStoreLimit},
		{"plain http server", one, StoreOptions{Server: "http://example.com"}, codeOther},
		{"missing file", filepath.Join(src, "nope"), StoreOptions{Server: "https://example.com"}, codeOther},
		{"nothing to send", "  \n", StoreOptions{Server: "https://example.com"}, codeOther},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := StartStoreSend(c.paths, &c.opts, newStoreRecorder())
			if err == nil {
				t.Fatal("start succeeded")
			}
			var f failure
			if json.Unmarshal([]byte(err.Error()), &f) != nil || f.Code != c.code {
				t.Fatalf("error %q, want code %q", err, c.code)
			}
		})
	}
}

func TestStoreSendOversizeFailsBeforeHashing(t *testing.T) {
	src := t.TempDir()
	big := filepath.Join(src, "big.bin")
	f, err := os.Create(big)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Truncate(storeMaxBytes + 1); err != nil { // sparse: no disk used
		t.Fatal(err)
	}
	f.Close()
	_, err = StartStoreSend(big, &StoreOptions{Server: "https://example.com"}, newStoreRecorder())
	var fl failure
	if err == nil || json.Unmarshal([]byte(err.Error()), &fl) != nil || fl.Code != codeStoreLimit {
		t.Fatalf("err = %v, want code %q", err, codeStoreLimit)
	}
}

func TestStoreSendServerLimitIsCoded(t *testing.T) {
	server := startTestStore(t, store.Config{MaxDownloads: 1})
	src := t.TempDir()
	rec, _ := storeSend(t, server, StoreOptions{Downloads: 5}, writeFiles(t, src, map[string]string{"a.txt": "x"}))
	if c := rec.failureCode(t); c != codeStoreLimit {
		t.Fatalf("code = %q (%s), want %q", c, rec.errMsg, codeStoreLimit)
	}
}

func TestStoreReceiveRejectsBadLinks(t *testing.T) {
	for _, link := range []string{
		"",
		"not a link",
		"http://example.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
		"https://example.com/s/short#v1.key",
	} {
		if _, err := StartStoreReceive(link, t.TempDir(), newStoreRecorder()); err == nil {
			t.Errorf("link %q accepted", link)
		}
	}
	if _, err := StartStoreReceive("https://example.com/s/x", "", newStoreRecorder()); err == nil {
		t.Error("empty output directory accepted")
	}
}

func TestStoreHoldsTheTransferLock(t *testing.T) {
	server := startTestStore(t, store.Config{})
	src := t.TempDir()
	_, receipt := storeSend(t, server, StoreOptions{}, writeFiles(t, src, map[string]string{"a.txt": "x"}))

	rec := newStoreRecorder()
	tr, err := StartStoreReceive(receipt.Link, t.TempDir(), rec)
	if err != nil {
		t.Fatal(err)
	}
	<-rec.fileReady
	if _, err := StartStoreSend(writeFiles(t, src, map[string]string{"b.txt": "y"})[0], &StoreOptions{Server: server}, newStoreRecorder()); err == nil ||
		!strings.Contains(err.Error(), "another transfer is active") {
		t.Fatalf("second start while one waits: err = %v", err)
	}
	tr.Cancel()
	rec.wait(t)
}

func TestClassifyStoreHTTP(t *testing.T) {
	cases := []struct {
		status int
		msg    string
		want   string
	}{
		{http.StatusNotFound, "", codeStoreExpired},
		{http.StatusGone, "stored transfer is no longer available", codeStoreExpired},
		{http.StatusRequestEntityTooLarge, "stored transfer exceeds the configured limit", codeStoreLimit},
		{http.StatusTooManyRequests, "stored-transfer creation rate exceeded", codeStoreLimit},
		{http.StatusInsufficientStorage, "stored-transfer quota is full", codeStoreLimit},
		{http.StatusBadRequest, "invalid stored-transfer declaration", codeStoreLimit},
		{http.StatusBadRequest, "invalid stored-transfer request", codeOther},
		{http.StatusLocked, "stored transfer is already claimed", codeOther},
	}
	for _, c := range cases {
		err := &storeclient.HTTPError{StatusCode: c.status, Message: c.msg}
		if got := classify(err); got != c.want {
			t.Errorf("classify(%d %q) = %q, want %q", c.status, c.msg, got, c.want)
		}
		// Wrapped, as storeclient does with %w.
		if got := classify(errors.Join(errors.New("upload"), err)); got != c.want {
			t.Errorf("classify(wrapped %d) = %q, want %q", c.status, got, c.want)
		}
	}
}

func TestStoreProgressBounds(t *testing.T) {
	cases := []struct {
		name string
		in   storeclient.Progress
		want progressState
	}{
		{"mid file", storeclient.Progress{FileIndex: 1, FileCount: 3, FileName: "b", FileBytes: 40, FileSize: 100, TotalBytes: 140, TotalSize: 300},
			progressState{CurrentFile: 1, TotalFiles: 3, FileName: "b", FileSent: 40, FileSize: 100, BytesFinished: 100, TotalSize: 300, Step: "transferring"}},
		{"counts past totals", storeclient.Progress{FileBytes: 150, FileSize: 100, TotalBytes: 900, TotalSize: 300},
			progressState{FileSent: 100, FileSize: 100, BytesFinished: 300, TotalSize: 300, Step: "transferring"}},
		{"negative", storeclient.Progress{FileBytes: -5, FileSize: 100, TotalBytes: -9, TotalSize: 300},
			progressState{FileSize: 100, TotalSize: 300, Step: "transferring"}},
	}
	for _, c := range cases {
		if got := storeProgress(c.in); got != c.want {
			t.Errorf("%s: got %+v, want %+v", c.name, got, c.want)
		}
	}
}

func TestKeepBothNames(t *testing.T) {
	dir := t.TempDir()
	writeFiles(t, dir, map[string]string{"a.txt": "", "A (1).txt": "", "noext": ""})
	files := []storecrypto.ManifestFile{{Name: "a.txt"}, {Name: "noext"}, {Name: "a (2).txt"}, {Name: "fresh.txt"}}
	keepBothNames(dir, files)
	var got []string
	for _, f := range files {
		got = append(got, f.Name)
	}
	// "a (1).txt" exists case-insensitively on macOS but not on Linux; either
	// way the renamed copy must not equal any other member or existing file.
	seen := map[string]bool{}
	for i, name := range got {
		if seen[strings.ToLower(name)] {
			t.Fatalf("duplicate name %q in %v", name, got)
		}
		seen[strings.ToLower(name)] = true
		if i != 3 && name == files[i].Name && (name == "a.txt" || name == "noext") {
			t.Fatalf("colliding %q kept its name", name)
		}
	}
	if got[3] != "fresh.txt" || got[2] != "a (2).txt" {
		t.Fatalf("non-colliding names changed: %v", got)
	}
	if !strings.HasPrefix(got[1], "noext (") || strings.Contains(got[1], ".") {
		t.Fatalf("extensionless rename = %q", got[1])
	}
}

func TestStoreCallbacksSurviveAPanickingDelegate(t *testing.T) {
	s := &session{delegate: &panicProgressDelegate{}}
	cb := s.storeCallbacks()
	cb.Progress(storeclient.Progress{})
	cb.Status("Hashing 1/1: a")
}

type panicProgressDelegate struct{ errorDelegate }

func (*panicProgressDelegate) OnProgress(string) { panic("delegate boom") }
