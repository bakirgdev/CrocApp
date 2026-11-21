package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/schollz/croc/v11/src/croc"
	"github.com/schollz/croc/v11/src/tailcattransport"
)

func TestSplitNonEmpty(t *testing.T) {
	tests := []struct {
		name string
		in   string
		sep  string
		want []string
	}{
		{"empty string", "", ",", nil},
		{"only separators", ",,,", ",", nil},
		{"only whitespace", "  \t ", ",", nil},
		{"single value", "9009", ",", []string{"9009"}},
		{"comma separated", "9009,9010,9011", ",", []string{"9009", "9010", "9011"}},
		{"trims whitespace", "  a , b\t,c  ", ",", []string{"a", "b", "c"}},
		{"drops empty segments", "a,,b, ,c,", ",", []string{"a", "b", "c"}},
		{"newline separated", "foo\nbar\nbaz", "\n", []string{"foo", "bar", "baz"}},
		{"newline drops blanks and trims", "\nfoo\n  \n bar \n\n", "\n", []string{"foo", "bar"}},
		{"newline keeps commas", "a,b\nc", "\n", []string{"a,b", "c"}},
		{"comma keeps newlines inside segment trimmed", "a,\nb\n", ",", []string{"a", "b"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := splitNonEmpty(tt.in, tt.sep)
			if len(got) == 0 && len(tt.want) == 0 {
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("splitNonEmpty(%q, %q) = %#v, want %#v", tt.in, tt.sep, got, tt.want)
			}
		})
	}
}

func mustBuildCrocOptions(t *testing.T, sender bool, secret string, o *Options) croc.Options {
	t.Helper()
	c, err := buildCrocOptions(sender, secret, o)
	if err != nil {
		t.Fatalf("buildCrocOptions: %v", err)
	}
	return c
}

func TestBuildCrocOptionsFieldMapping(t *testing.T) {
	o := &Options{
		RelayAddress:   "relay4.example:9009",
		RelayAddress6:  "relay6.example:9009",
		RelayPassword:  "relaypass",
		PeerIP:         "10.0.0.1:9100",
		ThrottleUpload: "500k",
		Exclude:        "node_modules\n .git \n\nbuild",
		DisableLocal:   true,
		OnlyLocal:      true,
		NoCompress:     true,
		ZipFolder:      true,
		GitIgnore:      true,
		Overwrite:      true,
		Ask:            true,
	}
	got := mustBuildCrocOptions(t, false, "secret-code", o)

	want := croc.Options{
		IsSender:         false,
		SharedSecret:     "secret-code",
		RelayAddress:     "relay4.example:9009",
		RelayAddress6:    "relay6.example:9009",
		RelayPassword:    "relaypass",
		RelayPorts:       []string{"9009", "9010", "9011", "9012", "9013"},
		IP:               "10.0.0.1:9100",
		MulticastAddress: "239.255.255.250",
		Curve:            "p256",
		ThrottleUpload:   "500k",
		DisableLocal:     true,
		OnlyLocal:        true,
		NoCompress:       true,
		ZipFolder:        true,
		GitIgnore:        true,
		Exclude:          []string{"node_modules", ".git", "build"},
		Overwrite:        true,
		NoPrompt:         false,
		Ask:              true,
		IgnoreStdin:      true,
		DisableClipboard: true,
		Quiet:            false,
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("buildCrocOptions mismatch\n got: %+v\nwant: %+v", got, want)
	}
}

// Each bool is checked on its own so one field mapped to another's value fails.
func TestBuildCrocOptionsBoolsMapIndependently(t *testing.T) {
	tests := []struct {
		name string
		set  func(o *Options)
		get  func(c croc.Options) bool
	}{
		{"DisableLocal", func(o *Options) { o.DisableLocal = true }, func(c croc.Options) bool { return c.DisableLocal }},
		{"OnlyLocal", func(o *Options) { o.OnlyLocal = true }, func(c croc.Options) bool { return c.OnlyLocal }},
		{"NoCompress", func(o *Options) { o.NoCompress = true }, func(c croc.Options) bool { return c.NoCompress }},
		{"ZipFolder", func(o *Options) { o.ZipFolder = true }, func(c croc.Options) bool { return c.ZipFolder }},
		{"GitIgnore", func(o *Options) { o.GitIgnore = true }, func(c croc.Options) bool { return c.GitIgnore }},
		{"Overwrite", func(o *Options) { o.Overwrite = true }, func(c croc.Options) bool { return c.Overwrite }},
		{"Ask", func(o *Options) { o.Ask = true }, func(c croc.Options) bool { return c.Ask }},
	}
	for i, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			o := &Options{}
			tt.set(o)
			c := mustBuildCrocOptions(t, false, "secret-code", o)
			for j, other := range tests {
				if got, want := other.get(c), i == j; got != want {
					t.Errorf("setting only %s: croc %s = %v, want %v", tt.name, other.name, got, want)
				}
			}
		})
	}
}

func TestBuildCrocOptionsNoPrompt(t *testing.T) {
	tests := []struct {
		sender     bool
		autoAccept bool
		want       bool
	}{
		{false, false, false},
		{false, true, true},
		{true, false, true},
		{true, true, true},
	}
	for _, tt := range tests {
		c := mustBuildCrocOptions(t, tt.sender, "secret-code", &Options{AutoAccept: tt.autoAccept})
		if c.NoPrompt != tt.want {
			t.Errorf("sender=%v autoAccept=%v: NoPrompt = %v, want %v", tt.sender, tt.autoAccept, c.NoPrompt, tt.want)
		}
		if c.IsSender != tt.sender {
			t.Errorf("sender=%v: IsSender = %v", tt.sender, c.IsSender)
		}
	}
}

func TestProgressSnapshot(t *testing.T) {
	files := []croc.FileInfo{
		{Name: "a.txt", Size: 100},
		{Name: "b.txt", Size: 250},
		{Name: "c.txt", Size: 1000},
	}
	tests := []struct {
		name      string
		files     []croc.FileInfo
		cur       int
		sent      int64
		requested bool
		connected bool
		want      progressState
	}{
		{
			name: "no files",
			want: progressState{Step: "waiting"},
		},
		{
			name:      "no files connected",
			connected: true,
			want:      progressState{Step: "connected"},
		},
		{
			name: "negative index", files: files, cur: -1,
			want: progressState{CurrentFile: -1, TotalFiles: 3, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "index equals len", files: files, cur: 3,
			want: progressState{CurrentFile: 3, TotalFiles: 3, BytesFinished: 1350, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "index past len", files: files, cur: 10,
			want: progressState{CurrentFile: 10, TotalFiles: 3, BytesFinished: 1350, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "first file", files: files, cur: 0,
			want: progressState{CurrentFile: 0, TotalFiles: 3, FileName: "a.txt", FileSize: 100, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "middle file", files: files, cur: 1,
			want: progressState{CurrentFile: 1, TotalFiles: 3, FileName: "b.txt", FileSize: 250, BytesFinished: 100, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "last file", files: files, cur: 2,
			want: progressState{CurrentFile: 2, TotalFiles: 3, FileName: "c.txt", FileSize: 1000, BytesFinished: 350, TotalSize: 1350, Step: "waiting"},
		},
		{
			name: "connected", files: files, cur: 1, connected: true,
			want: progressState{CurrentFile: 1, TotalFiles: 3, FileName: "b.txt", FileSize: 250, BytesFinished: 100, TotalSize: 1350, Step: "connected"},
		},
		{
			name: "transferring by bytes sent", files: files, cur: 1, sent: 42, connected: true,
			want: progressState{CurrentFile: 1, TotalFiles: 3, FileName: "b.txt", FileSize: 250, FileSent: 42, BytesFinished: 100, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "transferring by bytes sent while not connected", files: files, cur: 0, sent: 1,
			want: progressState{CurrentFile: 0, TotalFiles: 3, FileName: "a.txt", FileSize: 100, FileSent: 1, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "current file complete", files: files, cur: 0, sent: 100, connected: true,
			want: progressState{CurrentFile: 0, TotalFiles: 3, FileName: "a.txt", FileSize: 100, FileSent: 100, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "bundle after the current file", files: files, cur: 0, sent: 150, connected: true,
			want: progressState{CurrentFile: 1, TotalFiles: 3, FileName: "b.txt", FileSize: 250, FileSent: 50, BytesFinished: 100, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "bundle into the last file", files: files, cur: 0, sent: 400, connected: true,
			want: progressState{CurrentFile: 2, TotalFiles: 3, FileName: "c.txt", FileSize: 1000, FileSent: 50, BytesFinished: 350, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "sent past the last file", files: files, cur: 1, sent: 5000, connected: true,
			want: progressState{CurrentFile: 2, TotalFiles: 3, FileName: "c.txt", FileSize: 1000, FileSent: 1000, BytesFinished: 350, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "transferring by recipient request", files: files, cur: 0, requested: true, connected: true,
			want: progressState{CurrentFile: 0, TotalFiles: 3, FileName: "a.txt", FileSize: 100, TotalSize: 1350, Step: "transferring"},
		},
		{
			name: "transferring by recipient request while not connected", files: files, cur: 0, requested: true,
			want: progressState{CurrentFile: 0, TotalFiles: 3, FileName: "a.txt", FileSize: 100, TotalSize: 1350, Step: "transferring"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := &session{client: &croc.Client{
				FilesToTransfer:           tt.files,
				FilesToTransferCurrentNum: tt.cur,
				TotalSent:                 tt.sent,
				Step3RecipientRequestFile: tt.requested,
			}}
			got := s.progressSnapshot(tt.connected)
			if got != tt.want {
				t.Fatalf("progressSnapshot(%v)\n got: %+v\nwant: %+v", tt.connected, got, tt.want)
			}
		})
	}
}

// Sizes in a file list are the sender's word: a peer can declare sizes whose
// sums overflow int64, so every reported size and sum is capped.
func TestProgressSnapshotCapsDeclaredSizes(t *testing.T) {
	s := &session{client: &croc.Client{
		FilesToTransfer: []croc.FileInfo{
			{Name: "x", Size: math.MaxInt64 - 10},
			{Name: "y", Size: math.MaxInt64 - 10},
			{Name: "z", Size: -5},
		},
		FilesToTransferCurrentNum: 2,
		TotalSent:                 math.MaxInt64,
	}}
	want := progressState{
		CurrentFile: 2, TotalFiles: 3, FileName: "z",
		BytesFinished: maxReportedBytes, TotalSize: maxReportedBytes, Step: "transferring",
	}
	if got := s.progressSnapshot(true); got != want {
		t.Fatalf("progressSnapshot\n got: %+v\nwant: %+v", got, want)
	}
}

func TestFileListJSONCapsDeclaredSizes(t *testing.T) {
	s := &session{client: &croc.Client{FilesToTransfer: []croc.FileInfo{
		{Name: "x", FolderRemote: ".", Size: math.MaxInt64},
		{Name: "y", FolderRemote: ".", Size: math.MaxInt64},
		{Name: "z", FolderRemote: ".", Size: -1},
	}}}
	var got struct {
		Files     []fileEntry `json:"files"`
		TotalSize int64       `json:"totalSize"`
	}
	if err := json.Unmarshal([]byte(s.fileListJSON()), &got); err != nil {
		t.Fatal(err)
	}
	if got.TotalSize != maxReportedBytes {
		t.Errorf("totalSize = %d, want %d", got.TotalSize, int64(maxReportedBytes))
	}
	for i, want := range []int64{maxReportedBytes, maxReportedBytes, 0} {
		if got.Files[i].Size != want {
			t.Errorf("files[%d].size = %d, want %d", i, got.Files[i].Size, want)
		}
	}
}

// A picked file whose name holds '*' is sent alone: croc globs any path with a
// '*', which would add every matching file next to it.
func TestSendFilesInfoTakesPathsLiterally(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"*.pdf", "a.pdf", "b.pdf", "[x]*", "[x]y", `a\*`} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(name), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{"*.pdf", "[x]*", `a\*`} {
		files, _, _, err := sendFilesInfo(context.Background(), []string{filepath.Join(dir, name)}, &Options{})
		if err != nil {
			t.Fatalf("%q: %v", name, err)
		}
		if len(files) != 1 || files[0].Name != name {
			var got []string
			for _, f := range files {
				got = append(got, f.Name)
			}
			t.Errorf("%q: sent %q, want only that file", name, got)
		}
	}
}

// Path lists cross the bridge joined by "\n". A picked name that ends in a
// space must stay that name, or the send picks up the sibling without it.
func TestSplitPathsKeepsNamesExact(t *testing.T) {
	got := splitPaths("/d/report.pdf \n\n /d/x\n")
	if want := []string{"/d/report.pdf ", " /d/x"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("splitPaths = %q, want %q", got, want)
	}
	if got := splitPaths(""); got != nil {
		t.Fatalf("splitPaths(\"\") = %q, want nil", got)
	}
}

func keysOf(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func assertKeys(t *testing.T, m map[string]any, want ...string) {
	t.Helper()
	sort.Strings(want)
	if got := keysOf(m); !reflect.DeepEqual(got, want) {
		t.Fatalf("JSON keys = %v, want %v", got, want)
	}
}

func TestFileListJSON(t *testing.T) {
	s := &session{client: &croc.Client{
		FilesToTransfer: []croc.FileInfo{
			{Name: "a.txt", FolderRemote: ".", Size: 10},
			{Name: "b.bin", FolderRemote: "sub/dir", Size: 90},
		},
		EmptyFoldersToTransfer: []croc.FileInfo{{Name: "e1"}, {Name: "e2"}},
	}}

	var got map[string]any
	if err := json.Unmarshal([]byte(s.fileListJSON()), &got); err != nil {
		t.Fatal(err)
	}
	assertKeys(t, got, "files", "emptyFolders", "totalSize")

	if got["emptyFolders"] != float64(2) {
		t.Errorf("emptyFolders = %v, want 2", got["emptyFolders"])
	}
	if got["totalSize"] != float64(100) {
		t.Errorf("totalSize = %v, want 100", got["totalSize"])
	}

	files, ok := got["files"].([]any)
	if !ok || len(files) != 2 {
		t.Fatalf("files = %#v, want 2 entries", got["files"])
	}
	wantFiles := []struct {
		name string
		size float64
	}{
		{filepath.Join(".", "a.txt"), 10},
		{filepath.Join("sub/dir", "b.bin"), 90},
	}
	for i, w := range wantFiles {
		entry, ok := files[i].(map[string]any)
		if !ok {
			t.Fatalf("files[%d] = %#v, want object", i, files[i])
		}
		assertKeys(t, entry, "name", "size")
		if entry["name"] != w.name {
			t.Errorf("files[%d].name = %v, want %q", i, entry["name"], w.name)
		}
		if entry["size"] != w.size {
			t.Errorf("files[%d].size = %v, want %v", i, entry["size"], w.size)
		}
	}
}

func TestProgressStateJSON(t *testing.T) {
	p := progressState{
		CurrentFile:   1,
		TotalFiles:    3,
		FileName:      "b.txt",
		FileSent:      42,
		FileSize:      250,
		BytesFinished: 100,
		TotalSize:     1350,
		Step:          "transferring",
	}
	b, err := json.Marshal(p)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatal(err)
	}
	assertKeys(t, got, "currentFile", "totalFiles", "fileName", "fileSent", "fileSize", "bytesFinished", "totalSize", "step")

	want := map[string]any{
		"currentFile":   float64(1),
		"totalFiles":    float64(3),
		"fileName":      "b.txt",
		"fileSent":      float64(42),
		"fileSize":      float64(250),
		"bytesFinished": float64(100),
		"totalSize":     float64(1350),
		"step":          "transferring",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("progress JSON = %v, want %v", got, want)
	}
}

// The interop harness greps these exact bytes.
func TestPayloadKeyOrder(t *testing.T) {
	if got, want := (summaryPayload{2, true, 42}).json(), `{"files":2,"success":true,"totalSize":42}`; got != want {
		t.Errorf("summary = %s, want %s", got, want)
	}
	if got, want := (fileListPayload{1, []fileEntry{{"a", 3}}, 3}).json(), `{"emptyFolders":1,"files":[{"name":"a","size":3}],"totalSize":3}`; got != want {
		t.Errorf("fileList = %s, want %s", got, want)
	}
}

func TestSummaryJSON(t *testing.T) {
	tests := []struct {
		name    string
		success bool
		files   []croc.FileInfo
		want    map[string]any
	}{
		{
			name:    "success",
			success: true,
			files:   []croc.FileInfo{{Name: "a", Size: 10}, {Name: "b", Size: 32}},
			want:    map[string]any{"success": true, "files": float64(2), "totalSize": float64(42)},
		},
		{
			name: "failure no files",
			want: map[string]any{"success": false, "files": float64(0), "totalSize": float64(0)},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := &session{client: &croc.Client{SuccessfulTransfer: tt.success, FilesToTransfer: tt.files}}
			var got map[string]any
			if err := json.Unmarshal([]byte(s.summaryJSON()), &got); err != nil {
				t.Fatal(err)
			}
			assertKeys(t, got, "success", "files", "totalSize")
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("summary JSON = %v, want %v", got, tt.want)
			}
		})
	}
}

func promptSession(sender bool, o croc.Options) *session {
	return newSession(&croc.Client{Options: o}, func() {}, nil, sender)
}

func acceptQuestion(files ...croc.FileInfo) croc.Question {
	return croc.Question{Kind: croc.QuestionAccept, Name: "sender-machine", Files: files, Required: true}
}

// The first question waits for respond, which may come before croc asks. An
// accept applies its policy to the live client before croc reads it; a decline
// leaves the Options' policy. A second respond is dropped.
func TestPromptAnswersFromRespond(t *testing.T) {
	for _, tt := range []struct {
		name                  string
		sender, early, accept bool
		policy                filePolicy
		wantRename, wantOverw bool
	}{
		{"receive accept keeps both", false, false, true, keepBoth, true, false},
		{"receive accept replace", false, false, true, replace, false, true},
		{"receive answer before the question", false, true, true, replace, false, true},
		{"receive decline", false, false, false, replace, true, false},
		{"send confirm before the question", true, true, true, replace, true, false},
		{"send decline", true, false, false, keepBoth, true, false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			var o croc.Options
			keepBoth.apply(&o)
			s := promptSession(tt.sender, o)
			q := acceptQuestion(croc.FileInfo{Name: "a.txt", Size: 3})
			if tt.sender {
				q = croc.Question{Kind: croc.QuestionSend, Name: "receiver-machine", Required: true}
			}
			if tt.early {
				s.respond(tt.accept, tt.policy)
			} else {
				go s.respond(tt.accept, tt.policy)
			}
			got, err := s.prompt(context.Background(), q)
			if err != nil || got != tt.accept {
				t.Fatalf("prompt = %v, %v; want %v", got, err, tt.accept)
			}
			s.respond(!tt.accept, keepBoth)
			if s.answer.accept != tt.accept {
				t.Error("a second respond replaced the first")
			}
			if c := s.client.Options; c.Rename != tt.wantRename || c.Overwrite != tt.wantOverw {
				t.Errorf("Rename=%v Overwrite=%v, want %v %v", c.Rename, c.Overwrite, tt.wantRename, tt.wantOverw)
			}
			if accepted := s.offer.Load() != nil; accepted != tt.accept {
				t.Errorf("offer recorded = %v, want %v", accepted, tt.accept)
			}
		})
	}
}

func TestPromptCancelUnblocks(t *testing.T) {
	s := promptSession(false, croc.Options{})
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if got, err := s.prompt(ctx, acceptQuestion()); got || !errors.Is(err, context.Canceled) {
		t.Fatalf("prompt = %v, %v; want false, context.Canceled", got, err)
	}
}

// Under AutoAccept croc asks without requiring an answer, except when the
// sender ran --ask, which needs a person the app does not ask.
func TestPromptAutoAccept(t *testing.T) {
	s := promptSession(false, croc.Options{NoPrompt: true})
	q := acceptQuestion()
	q.Required = false
	if got, _ := s.prompt(context.Background(), q); !got {
		t.Error("AutoAccept refused an offer croc did not require an answer for")
	}
	if got, _ := s.prompt(context.Background(), acceptQuestion()); got {
		t.Error("AutoAccept accepted a sender's --ask offer")
	}
}

// Overwrite questions (zip members, non-empty folders) follow the policy.
func TestPromptOverwriteFollowsPolicy(t *testing.T) {
	for _, p := range []filePolicy{keepBoth, replace} {
		var o croc.Options
		p.apply(&o)
		s := promptSession(false, o)
		got, err := s.prompt(context.Background(), croc.Question{Kind: croc.QuestionOverwrite, Name: "dir/a.txt", Required: true})
		if err != nil || got != (p == replace) {
			t.Errorf("policy %v: prompt = %v, %v", p, got, err)
		}
	}
}

// After an accept, croc's re-ask on a reconnect gets yes only for the same
// offer (#226).
func TestPromptReaskAfterReconnect(t *testing.T) {
	file := croc.FileInfo{FolderRemote: "dir", Name: "a.txt", Size: 3}
	hashed := file
	hashed.Hash = []byte{1, 2}
	with := func(f func(*croc.FileInfo)) croc.FileInfo {
		c := hashed
		f(&c)
		return c
	}
	tests := []struct {
		name   string
		policy filePolicy
		q      croc.Question
		want   bool
	}{
		{"same offer", keepBoth, acceptQuestion(hashed), true},
		{"hash missing on one side", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Hash = nil })), true},
		{"name Keep Both gave a finished file", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Name = "a (2).txt" })), true},
		{"Keep Both name under Replace", replace, acceptQuestion(with(func(f *croc.FileInfo) { f.Name = "a (2).txt" })), false},
		{"same offer under Replace", replace, acceptQuestion(hashed), true},
		{"now an archive to extract", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.TempFile = true })), false},
		{"other name", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Name = "b.txt" })), false},
		{"other folder", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.FolderRemote = "other" })), false},
		{"other size", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Size = 4 })), false},
		{"other hash", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Hash = []byte{9} })), false},
		{"executable bit flipped", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Mode = 0o755 })), false},
		{"now a symlink", keepBoth, acceptQuestion(with(func(f *croc.FileInfo) { f.Symlink = "x" })), false},
		{"extra file", keepBoth, acceptQuestion(hashed, file), false},
		{"other sender", keepBoth, croc.Question{Kind: croc.QuestionAccept, Name: "other-machine", Files: []croc.FileInfo{hashed}, Required: true}, false},
		{"extra empty folder", keepBoth, croc.Question{Kind: croc.QuestionAccept, Name: "sender-machine", Files: []croc.FileInfo{hashed}, EmptyFolders: 1, Required: true}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := promptSession(false, croc.Options{})
			s.respond(true, tt.policy)
			if got, _ := s.prompt(context.Background(), acceptQuestion(hashed)); !got {
				t.Fatal("first ask refused")
			}
			if got, _ := s.prompt(context.Background(), tt.q); got != tt.want {
				t.Errorf("re-ask = %v, want %v", got, tt.want)
			}
		})
	}
	// A sender's Ask asks once per file request; the same receiver gets the
	// same answer without a second respond.
	s := promptSession(true, croc.Options{NoPrompt: true, Ask: true})
	s.respond(true, keepBoth)
	send := croc.Question{Kind: croc.QuestionSend, Name: "receiver-machine", Required: true}
	for i := range 3 {
		if got, _ := s.prompt(context.Background(), send); !got {
			t.Fatalf("send question %d refused", i)
		}
	}
	send.Name = "other-machine"
	if got, _ := s.prompt(context.Background(), send); got {
		t.Error("another receiver got the confirmed answer")
	}
}

func TestKeptName(t *testing.T) {
	for _, tt := range []struct {
		name string
		want bool
	}{
		{"a.tar.gz", true},
		{"a.tar (1).gz", true},
		{"a.tar (12).gz", true},
		{"a.tar (0).gz", false},
		{"a.tar (x).gz", false},
		{"a.tar ().gz", false},
		{"a.tar (1)", false},
		{"b.tar (1).gz", false},
		{"a.tar.gz (1)", false},
		{"a.tar (01).gz", false},
		{"a.tar (+1).gz", false},
	} {
		if got := keptName("a.tar.gz", tt.name); got != tt.want {
			t.Errorf("keptName(a.tar.gz, %q) = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestParsePolicy(t *testing.T) {
	for in, want := range map[string]filePolicy{
		PolicyKeepBoth: keepBoth,
		PolicyReplace:  replace,
		"":             keepBoth,
		"Replace":      keepBoth,
		"overwrite":    keepBoth,
	} {
		if got := parsePolicy(in); got != want {
			t.Errorf("parsePolicy(%q) = %v, want %v", in, got, want)
		}
	}
}

// The engine ships relay-only (croc_no_tailcat, scripts/build-xcframework.sh),
// so every build and test of this package must carry the tag, or the tests
// would exercise an engine that is not the shipped one.
func TestBuildIsRelayOnly(t *testing.T) {
	if tailcattransport.Available() {
		t.Fatal("Tailcat is compiled in: build and test with -tags croc_no_tailcat (docs/BUILDING.md, \"Format and lint\")")
	}
	for _, sender := range []bool{true, false} {
		c := mustBuildCrocOptions(t, sender, "secret-code", &Options{})
		if c.Transport != "" {
			t.Errorf("sender=%v: croc Transport = %q, want it left at croc's auto", sender, c.Transport)
		}
	}
}

// croc never gets Rename and Overwrite both false: it would ask per file.
// Rename wins when both are set.
func TestBuildCrocOptionsFilePolicy(t *testing.T) {
	tests := []struct {
		overwrite, rename     bool
		wantRename, wantOverw bool
	}{
		{false, false, true, false},
		{false, true, true, false},
		{true, false, false, true},
		{true, true, true, false},
	}
	for _, tt := range tests {
		for _, sender := range []bool{false, true} {
			c := mustBuildCrocOptions(t, sender, "secret-code", &Options{Overwrite: tt.overwrite, Rename: tt.rename})
			if c.Rename != tt.wantRename || c.Overwrite != tt.wantOverw {
				t.Errorf("Overwrite=%v Rename=%v sender=%v: croc Rename=%v Overwrite=%v, want %v %v",
					tt.overwrite, tt.rename, sender, c.Rename, c.Overwrite, tt.wantRename, tt.wantOverw)
			}
		}
	}
}

type errorDelegate struct{ errors []string }

func (d *errorDelegate) OnCodeReady(string) {}
func (d *errorDelegate) OnConnected()       {}
func (d *errorDelegate) OnFileList(string)  {}
func (d *errorDelegate) OnProgress(string)  {}
func (d *errorDelegate) OnText(string)      {}
func (d *errorDelegate) OnDone(string)      {}
func (d *errorDelegate) OnError(m string)   { d.errors = append(d.errors, m) }
func (d *errorDelegate) OnStored(string)    {}

func mkSendFolder(t *testing.T, dir string) string {
	t.Helper()
	src := filepath.Join(dir, "src")
	if err := os.MkdirAll(src, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "a.txt"), []byte("a"), 0o644); err != nil {
		t.Fatal(err)
	}
	return src
}

func assertNoZip(t *testing.T, dir string) {
	t.Helper()
	if zips, _ := filepath.Glob(filepath.Join(dir, "*.zip")); len(zips) != 0 {
		t.Fatalf("temp zip left behind: %v", zips)
	}
}

// croc deletes the zip it builds for a zipped-folder send only when the send
// succeeds; otherwise the caller must (the CLI does it on exit).
func TestRunRemovesMarkedZip(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	mkSendFolder(t, dir)
	if _, _, _, err := croc.GetFilesInfoWithExactExclusions([]string{"src"}, true, false, nil, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "src.zip")); err != nil {
		t.Fatalf("croc did not build the zip: %v", err)
	}
	d := &errorDelegate{}
	pollDone := make(chan struct{})
	close(pollDone)
	s := &session{delegate: d, done: make(chan struct{}), pollDone: pollDone}

	s.run(func() error { return errors.New("relay down") }, dir, func() {})

	assertNoZip(t, dir)
	if len(d.errors) != 1 {
		t.Fatalf("OnError calls = %v, want one", d.errors)
	}
}

func TestSendSetupFailureRemovesZip(t *testing.T) {
	dir := t.TempDir()
	src := mkSendFolder(t, dir)
	o := NewOptionsDefault()
	o.Code = "zipfail-test"
	o.WorkDir = dir
	o.ZipFolder = true
	o.ThrottleUpload = "xk" // croc.NewCtx panics on an unparsable rate, after the zip exists

	if _, err := StartSend(src, "", o, &errorDelegate{}); err == nil {
		t.Fatal("StartSend with an unparsable throttle: want error")
	}

	assertNoZip(t, dir)
}

type fileListRecorder struct {
	errorDelegate
	lists []string
}

func (d *fileListRecorder) OnFileList(l string) { d.lists = append(d.lists, l) }

// A receive that finishes before poll's first tick must still report its list.
func TestPollReportsFileListOfTransferEndedWithinATick(t *testing.T) {
	d := &fileListRecorder{}
	s := &session{
		client:   &croc.Client{FilesToTransfer: []croc.FileInfo{{Name: "a.txt", FolderRemote: ".", Size: 5}}},
		delegate: d, done: make(chan struct{}), pollDone: make(chan struct{}),
	}
	close(s.done)
	s.poll()
	if len(d.lists) != 1 {
		t.Fatalf("OnFileList called %d times, want 1", len(d.lists))
	}
}

func FuzzSplitPaths(f *testing.F) {
	for _, s := range []string{"", "/d/report.pdf \n\n /d/x\n", "a\nb\nc", "\n\n", " a \n b"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, joined string) {
		got := splitPaths(joined)
		var want []string
		for _, line := range strings.Split(joined, "\n") {
			if line != "" {
				want = append(want, line)
			}
		}
		if !reflect.DeepEqual(got, want) {
			t.Fatalf("splitPaths(%q) = %q, want every non-empty line verbatim: %q", joined, got, want)
		}
		for _, p := range got {
			if p == "" || strings.Contains(p, "\n") {
				t.Fatalf("splitPaths(%q) returned entry %q", joined, p)
			}
		}
		if again := splitPaths(strings.Join(got, "\n")); !reflect.DeepEqual(again, got) {
			t.Fatalf("splitPaths does not round-trip: %q then %q", got, again)
		}
	})
}

// lifecycleRecorder collects a session's code and terminal events from the
// goroutines of run, the cancel watchdog and the test. onEnd runs inside the
// terminal call, before it returns.
type lifecycleRecorder struct {
	mu        sync.Mutex
	codes     []string
	codeReady int
	onEnd     func()
	ended     chan struct{}
	once      sync.Once
}

func newLifecycleRecorder() *lifecycleRecorder {
	return &lifecycleRecorder{ended: make(chan struct{})}
}

func (r *lifecycleRecorder) OnCodeReady(string) {
	r.mu.Lock()
	r.codeReady++
	r.mu.Unlock()
}
func (r *lifecycleRecorder) OnConnected()      {}
func (r *lifecycleRecorder) OnFileList(string) {}
func (r *lifecycleRecorder) OnProgress(string) {}
func (r *lifecycleRecorder) OnText(string)     {}
func (r *lifecycleRecorder) OnStored(string)   {}
func (r *lifecycleRecorder) OnDone(string)     { r.end("done") }
func (r *lifecycleRecorder) OnError(m string) {
	var f failure
	if err := json.Unmarshal([]byte(m), &f); err != nil {
		f.Code = "undecodable: " + m
	}
	r.end(f.Code)
}

func (r *lifecycleRecorder) end(code string) {
	r.mu.Lock()
	r.codes = append(r.codes, code)
	r.mu.Unlock()
	if r.onEnd != nil {
		r.onEnd()
	}
	r.once.Do(func() { close(r.ended) })
}

func (r *lifecycleRecorder) wait(t *testing.T) {
	t.Helper()
	select {
	case <-r.ended:
	case <-time.After(20 * time.Second):
		t.Fatal("no terminal event")
	}
}

func (r *lifecycleRecorder) terminalCodes() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.codes...)
}

func startCode(t *testing.T, err error) string {
	t.Helper()
	if err == nil {
		t.Fatal("start succeeded, want an error")
	}
	return decodeFailure(t, err.Error()).Code
}

// The lock is free inside the terminal call, so a consumer that starts the
// next transfer the moment it sees OnDone or OnError never finds it busy.
func TestRunFreesTheLockBeforeTheTerminalEvent(t *testing.T) {
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for _, xferErr := range []error{nil, errors.New("peer error: refusing files")} {
		if err := lockTransfer(); err != nil {
			t.Fatal(err)
		}
		heldAtEnd := false
		d := newLifecycleRecorder()
		d.onEnd = func() {
			heldAtEnd = !activeMu.TryLock()
			if !heldAtEnd {
				activeMu.Unlock()
			}
		}
		pollDone := make(chan struct{})
		close(pollDone)
		s := &session{client: &croc.Client{}, delegate: d, done: make(chan struct{}), pollDone: pollDone}
		s.run(func() error { return xferErr }, wd, activeMu.Unlock)
		if heldAtEnd {
			t.Errorf("xfer error %v: the lock was still held during the terminal call", xferErr)
		}
		if got := d.terminalCodes(); len(got) != 1 {
			t.Errorf("xfer error %v: terminal events %v, want one", xferErr, got)
		}
	}
}

// A real receive that fails at once is started again from inside its own
// OnError, the earliest moment a consumer can react: it must get the engine.
func TestStartFromTheTerminalEventGetsTheEngine(t *testing.T) {
	o := NewOptionsDefault()
	o.RelayAddress = "127.0.0.1:1"
	o.DisableLocal = true
	o.OutDir = t.TempDir()
	second := newLifecycleRecorder()
	var restartErr error
	first := newLifecycleRecorder()
	first.onEnd = func() { _, restartErr = StartReceive("restart-bravo-two", o, second) }
	if _, err := StartReceive("restart-alpha-one", o, first); err != nil {
		t.Fatal(err)
	}
	first.wait(t)
	if restartErr != nil {
		t.Fatalf("start from OnError: %v", restartErr)
	}
	second.wait(t)
	for name, d := range map[string]*lifecycleRecorder{"first": first, "second": second} {
		if got := d.terminalCodes(); !slices.Equal(got, []string{codeRelayUnreachable}) {
			t.Errorf("%s receive ended %v, want [%s]", name, got, codeRelayUnreachable)
		}
	}
}

// A start while a transfer holds the engine is refused at once, with its own
// code, which CrocKit turns into CrocEngineError.transferActive.
func TestConcurrentStartIsRefused(t *testing.T) {
	if err := lockTransfer(); err != nil {
		t.Fatal(err)
	}
	defer activeMu.Unlock()
	o := NewOptionsDefault()
	o.OutDir = t.TempDir()
	_, err := StartReceive("busy-alpha-bravo", o, newLifecycleRecorder())
	if code := startCode(t, err); code != codeTransferActive {
		t.Errorf("start while busy: code %s, want %s", code, codeTransferActive)
	}
	o.Code = "busy-charlie-delta"
	_, err = StartSend("/nonexistent", "", o, newLifecycleRecorder())
	if code := startCode(t, err); code != codeTransferActive {
		t.Errorf("send while busy: code %s, want %s", code, codeTransferActive)
	}
}

// A croc call that outlives a cancel by stuckAfter is reported as engineStuck,
// later starts fail fast with that code, and the engine frees itself if croc
// returns after all, without a second terminal event.
func TestCancelWatchdogReportsAStuckSession(t *testing.T) {
	defer func(d time.Duration) { stuckAfter = d }(stuckAfter)
	stuckAfter = 50 * time.Millisecond
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := lockTransfer(); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	unblock := make(chan struct{})
	d := newLifecycleRecorder()
	pollDone := make(chan struct{})
	close(pollDone)
	s := &session{ctxCancel: cancel, delegate: d, done: make(chan struct{}), pollDone: pollDone}
	returned := make(chan struct{})
	go func() {
		defer close(returned)
		s.run(func() error { <-unblock; return ctx.Err() }, wd, activeMu.Unlock)
	}()

	s.cancel()
	d.wait(t)
	if got := d.terminalCodes(); !slices.Equal(got, []string{codeEngineStuck}) {
		t.Fatalf("terminal events %v, want [%s]", got, codeEngineStuck)
	}

	o := NewOptionsDefault()
	o.OutDir = t.TempDir()
	begin := time.Now()
	_, err = StartReceive("after-stuck-alpha", o, newLifecycleRecorder())
	if code := startCode(t, err); code != codeEngineStuck {
		t.Errorf("start while stuck: code %s, want %s", code, codeEngineStuck)
	}
	if took := time.Since(begin); took > time.Second {
		t.Errorf("start while stuck took %v, want it to fail fast", took)
	}

	close(unblock)
	<-returned
	if err := lockTransfer(); err != nil {
		t.Fatalf("after croc returned: %v", err)
	}
	activeMu.Unlock()
	if got := d.terminalCodes(); len(got) != 1 {
		t.Errorf("terminal events %v, want only the watchdog's", got)
	}
}

// A cancel that croc honours in time leaves the watchdog silent.
func TestCancelWatchdogQuietWhenCrocReturns(t *testing.T) {
	defer func(d time.Duration) { stuckAfter = d }(stuckAfter)
	stuckAfter = 200 * time.Millisecond
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := lockTransfer(); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	d := newLifecycleRecorder()
	pollDone := make(chan struct{})
	close(pollDone)
	s := &session{ctxCancel: cancel, delegate: d, done: make(chan struct{}), pollDone: pollDone}
	returned := make(chan struct{})
	go func() {
		defer close(returned)
		s.run(func() error { <-ctx.Done(); return ctx.Err() }, wd, activeMu.Unlock)
	}()
	s.cancel()
	<-returned
	time.Sleep(2 * stuckAfter)
	if got := d.terminalCodes(); !slices.Equal(got, []string{codeCancelled}) {
		t.Errorf("terminal events %v, want [%s]", got, codeCancelled)
	}
	if err := lockTransfer(); err != nil {
		t.Fatal(err)
	}
	activeMu.Unlock()
}

func TestSendFilesInfoAppliesExcludePatterns(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "proj", "config"), 0o700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"proj/keep.txt", "proj/config/Credentials.json", "proj/.env"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("x"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	files, _, _, err := sendFilesInfo(context.Background(), []string{filepath.Join(dir, "proj")}, &Options{Exclude: "config/credentials.json\n.ENV"})
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 1 || files[0].Name != "keep.txt" {
		t.Fatalf("got %+v, want only keep.txt", files)
	}

	// A file the user picked itself is sent whatever the patterns say.
	picked, _, folders, err := sendFilesInfo(context.Background(), []string{filepath.Join(dir, "proj", ".env")}, &Options{Exclude: ".env"})
	if err != nil || len(picked) != 1 || folders != 0 {
		t.Fatalf("picked file: got %+v, %d folders, %v", picked, folders, err)
	}

	// A folder with nothing left says so with its own code.
	only := filepath.Join(dir, "only")
	if err := os.Mkdir(only, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(only, "a.env"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := sendFilesInfo(context.Background(), []string{only}, &Options{Exclude: ".env"}); err == nil || classify(err) != codeNothingToSend {
		t.Fatalf("all excluded: got %v", err)
	}
}
