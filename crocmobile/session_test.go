package crocmobile

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"

	"github.com/schollz/croc/v10/src/croc"
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

func TestBuildCrocOptionsFieldMapping(t *testing.T) {
	o := &Options{
		RelayAddress:   "relay4.example:9009",
		RelayAddress6:  "relay6.example:9009",
		RelayPassword:  "relaypass",
		RelayPorts:     "9009, 9010,,9011",
		Curve:          "siec",
		HashAlgorithm:  "imohash",
		ThrottleUpload: "500k",
		Exclude:        "node_modules\n .git \n\nbuild",
		DisableLocal:   true,
		OnlyLocal:      true,
		NoCompress:     true,
		ZipFolder:      true,
		GitIgnore:      true,
		Overwrite:      true,
		Ask:            true,
		NoMultiplexing: true,
	}
	got := buildCrocOptions(false, "secret-code", o)

	want := croc.Options{
		IsSender:         false,
		SharedSecret:     "secret-code",
		RelayAddress:     "relay4.example:9009",
		RelayAddress6:    "relay6.example:9009",
		RelayPassword:    "relaypass",
		RelayPorts:       []string{"9009", "9010", "9011"},
		Curve:            "siec",
		HashAlgorithm:    "imohash",
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
		NoMultiplexing:   true,
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
		{"NoMultiplexing", func(o *Options) { o.NoMultiplexing = true }, func(c croc.Options) bool { return c.NoMultiplexing }},
	}
	for i, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			o := &Options{}
			tt.set(o)
			c := buildCrocOptions(false, "secret-code", o)
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
		c := buildCrocOptions(tt.sender, "secret-code", &Options{AutoAccept: tt.autoAccept})
		if c.NoPrompt != tt.want {
			t.Errorf("sender=%v autoAccept=%v: NoPrompt = %v, want %v", tt.sender, tt.autoAccept, c.NoPrompt, tt.want)
		}
		if c.IsSender != tt.sender {
			t.Errorf("sender=%v: IsSender = %v", tt.sender, c.IsSender)
		}
	}
}

func TestBuildCrocOptionsFixedValues(t *testing.T) {
	for _, sender := range []bool{true, false} {
		c := buildCrocOptions(sender, "my-secret", &Options{})
		if c.SharedSecret != "my-secret" {
			t.Errorf("sender=%v: SharedSecret = %q", sender, c.SharedSecret)
		}
		if !c.IgnoreStdin {
			t.Errorf("sender=%v: IgnoreStdin = false, want true", sender)
		}
		if !c.DisableClipboard {
			t.Errorf("sender=%v: DisableClipboard = false, want true", sender)
		}
		if c.Quiet {
			t.Errorf("sender=%v: Quiet = true, want false", sender)
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

func TestRespond(t *testing.T) {
	tests := []struct {
		name    string
		accept  bool
		answers int
		want    string
	}{
		{"accept zero value counts as one", true, 0, "y\n"},
		{"accept negative counts as one", true, -2, "y\n"},
		{"accept one", true, 1, "y\n"},
		{"accept three", true, 3, "y\ny\ny\n"},
		{"decline", false, 0, "n\n"},
		{"decline ignores answer count", false, 3, "n\n"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pr, pw, err := os.Pipe()
			if err != nil {
				t.Fatal(err)
			}
			defer pr.Close()
			s := &session{promptW: pw, promptAnswers: tt.answers}

			s.respond(tt.accept)

			if s.promptW != nil {
				t.Error("promptW not nil after respond")
			}
			got, err := io.ReadAll(pr)
			if err != nil {
				t.Fatal(err)
			}
			if string(got) != tt.want {
				t.Fatalf("pipe received %q, want %q", got, tt.want)
			}

			s.respond(true) // no-op: promptW already closed and nil
			s.respond(false)
			if s.promptW != nil {
				t.Error("promptW not nil after repeated respond")
			}
		})
	}
}

func TestRespondWithoutPrompt(t *testing.T) {
	s := &session{}
	s.respond(true)
	s.respond(false)
}

func TestClosePromptIdempotent(t *testing.T) {
	pr, pw, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer pr.Close()
	s := &session{promptW: pw}

	s.closePrompt()
	if s.promptW != nil {
		t.Fatal("promptW not nil after closePrompt")
	}
	if got, err := io.ReadAll(pr); err != nil || len(got) != 0 {
		t.Fatalf("read after close = %q, %v; want EOF with no data", got, err)
	}
	s.closePrompt()

	var empty session
	empty.closePrompt()
}
