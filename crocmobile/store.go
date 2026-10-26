package crocmobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"runtime/debug"
	"strings"
	"time"

	"github.com/schollz/croc/v11/src/receivefs"
	"github.com/schollz/croc/v11/src/storeclient"
	"github.com/schollz/croc/v11/src/storecrypto"
)

// Limits a stored upload checks before it hashes or uploads anything. They
// mirror croc's store defaults (store.DefaultMaxTransfer, storecrypto.MaxFiles),
// so a server configured with a lower cap still refuses at upload time with
// codeStoreLimit.
const (
	storeMaxBytes     int64 = 1 << 30
	storeMaxFiles           = storecrypto.MaxFiles
	storeMaxDownloads       = 100
	storeRevokeWait         = 30 * time.Second
)

// StoreOptions configures the stored-transfer calls. StartStoreReceive and
// RevokeStored read only the proxies; nil means no proxy.
type StoreOptions struct {
	Server          string // stored-transfer origin; https, or http on loopback
	Downloads       int    // verified downloads allowed, 1 to 100; 0 means 1
	LifetimeSeconds int    // storage lifetime; 0 means one day, the server may cap it
	Socks5Proxy     string // as Options.Socks5Proxy
	HTTPProxy       string // as Options.HTTPProxy
}

// storedReceipt is the OnStored payload: everything the sender needs to share
// the transfer (link) and to take it back (origin, id, uploadToken). link
// carries the decryption key in its fragment, so it is a secret.
type storedReceipt struct {
	ID          string `json:"id"`
	Origin      string `json:"origin"`
	UploadToken string `json:"uploadToken"`
	Link        string `json:"link"`
	ExpiresAt   string `json:"expiresAt"` // RFC 3339, UTC, whole seconds
	Downloads   int    `json:"downloads"`
}

// storeReply is what Respond hands a stored receive that waits at its preview.
type storeReply struct {
	accept bool
	policy filePolicy
}

// validateStoreOrigin applies the https rule (loopback exempt) to a server
// origin the way storecrypto applies it to a link, without a real share.
func validateStoreOrigin(origin string) error {
	probe := storecrypto.Share{
		Origin:    origin,
		ID:        storecrypto.EncodeBase64URL(make([]byte, storecrypto.TransferIDLen)),
		MasterKey: make([]byte, storecrypto.KeySize),
	}
	_, err := probe.BrowserURL()
	return err
}

// checkStoreLimits refuses what the server would refuse after the upload has
// been hashed: too many files or too many bytes. Anything else about the paths
// (folders, symlinks, duplicate names) is left to storeclient.
func checkStoreLimits(paths []string) error {
	if len(paths) == 0 {
		return errors.New("nothing to send")
	}
	if len(paths) > storeMaxFiles {
		return &codedError{codeStoreLimit, fmt.Errorf("a stored transfer holds at most %d files", storeMaxFiles)}
	}
	var total int64
	for _, p := range paths {
		info, err := os.Lstat(p)
		if err != nil {
			return err
		}
		if info.Mode().IsRegular() {
			total += info.Size()
		}
	}
	if total > storeMaxBytes {
		return &codedError{codeStoreLimit, fmt.Errorf("a stored transfer holds at most %d bytes", storeMaxBytes)}
	}
	return nil
}

// StartStoreSend uploads the newline-joined files to a stored-transfer server
// and reports the receipt through OnStored, then OnDone. The file contents are
// encrypted on this device; the server never sees names or keys. Shares
// activeMu with live transfers: one transfer at a time.
func StartStoreSend(pathsJoined string, o *StoreOptions, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	if o == nil {
		return nil, startError(errors.New("store options required"))
	}
	if d == nil {
		return nil, startError(errors.New("delegate required"))
	}
	paths := splitPaths(pathsJoined)
	if err := checkStoreLimits(paths); err != nil {
		return nil, startError(err)
	}
	downloads := o.Downloads
	if downloads == 0 {
		downloads = 1
	}
	if downloads < 1 || downloads > storeMaxDownloads {
		return nil, startError(&codedError{codeStoreLimit, fmt.Errorf("downloads must be between 1 and %d", storeMaxDownloads)})
	}
	if o.LifetimeSeconds < 0 {
		return nil, startError(errors.New("lifetime cannot be negative"))
	}
	if err := validateStoreOrigin(o.Server); err != nil {
		return nil, startError(err)
	}
	client, err := storeClient(o)
	if err != nil {
		return nil, startError(err)
	}
	server, lifetime := o.Server, time.Duration(o.LifetimeSeconds)*time.Second
	t, err = startStoreSession(d, func(ctx context.Context, s *session) (storeSummary, error) {
		result, err := client.UploadWithOptions(ctx, server, paths,
			storeclient.UploadOptions{Downloads: downloads, Expiration: lifetime}, s.storeCallbacks())
		if err != nil {
			return storeSummary{}, err
		}
		link, err := result.Share.BrowserURL()
		if err != nil {
			return storeSummary{}, err
		}
		b, err := json.Marshal(storedReceipt{
			ID: result.Share.ID, Origin: result.Share.Origin, UploadToken: result.UploadToken, Link: link,
			ExpiresAt: result.ExpiresAt.UTC().Truncate(time.Second).Format(time.RFC3339), Downloads: result.Downloads,
		})
		if err != nil {
			return storeSummary{}, err
		}
		s.delegate.OnStored(string(b))
		return storeSummary{files: len(paths), totalSize: sizeOfFiles(paths)}, nil
	})
	if err != nil {
		return nil, startError(err)
	}
	return t, nil
}

// StartStoreReceive opens a stored-transfer link: it reads the manifest
// without claiming the transfer, reports it through OnFileList, and waits for
// Respond. On accept it downloads into outDir, applying Respond's policy to
// names that already exist, then reports OnDone. Decline ends it with the
// "refused" failure and leaves the transfer unclaimed.
func StartStoreReceive(link, outDir string, o *StoreOptions, d Delegate) (t *Transfer, err error) {
	defer func() {
		if r := recover(); r != nil {
			t, err = nil, startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	if d == nil {
		return nil, startError(errors.New("delegate required"))
	}
	if outDir == "" {
		return nil, startError(errors.New("output directory required"))
	}
	share, err := storecrypto.ParseShare(link)
	if err != nil {
		return nil, startError(err)
	}
	client, err := storeClient(o)
	if err != nil {
		return nil, startError(err)
	}
	t, err = startStoreSession(d, func(ctx context.Context, s *session) (storeSummary, error) {
		manifest, _, err := client.Inspect(ctx, share)
		if err != nil {
			return storeSummary{}, err
		}
		if err = storecrypto.ValidateManifest(manifest, 1<<40); err != nil {
			return storeSummary{}, err
		}
		s.delegate.OnFileList(storeFileListJSON(manifest))
		var answer storeReply
		select {
		case answer = <-s.storeAnswer:
		case <-ctx.Done():
			return storeSummary{}, ctx.Err()
		}
		if !answer.accept {
			return storeSummary{}, &codedError{codeRefused, errors.New("refused files")}
		}
		if answer.policy == keepBoth {
			keepBothNames(outDir, manifest.Files)
		}
		if err = client.Receive(ctx, share, manifest, outDir, s.storeCallbacks()); err != nil {
			return storeSummary{}, err
		}
		return storeSummary{files: len(manifest.Files), totalSize: manifestTotal(manifest)}, nil
	})
	if err != nil {
		return nil, startError(err)
	}
	return t, nil
}

// RevokeStored deletes a stored transfer from its server using the sender's
// receipt. A transfer the server no longer has (404, 410) counts as revoked.
// Blocking; it does not take the transfer lock, so a History row can revoke
// while another transfer runs.
func RevokeStored(origin, id, token string, o *StoreOptions) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = startError(fmt.Errorf("croc panic: %v\n%s", r, debug.Stack()))
		}
	}()
	// Revoke authenticates with the token alone, but storeclient validates the
	// whole share first, so a zero key stands in for the one the receipt keeps
	// in its link.
	share := storecrypto.Share{Origin: origin, ID: id, MasterKey: make([]byte, storecrypto.KeySize)}
	client, err := storeClient(o)
	if err != nil {
		return startError(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), storeRevokeWait)
	defer cancel()
	err = client.Revoke(ctx, share, token)
	var httpErr *storeclient.HTTPError
	if errors.As(err, &httpErr) && (httpErr.StatusCode == http.StatusNotFound || httpErr.StatusCode == http.StatusGone) {
		return nil
	}
	return startError(err)
}

type storeSummary struct {
	files     int
	totalSize int64
}

// startStoreSession takes the process-global lock and runs work on a new
// goroutine, which releases the lock after the terminal delegate call. Unlike
// startSession it touches no cwd, stdin or stdout: storeclient takes explicit
// paths.
func startStoreSession(d Delegate, work func(context.Context, *session) (storeSummary, error)) (*Transfer, error) {
	if err := lockTransfer(); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(context.Background())
	s := &session{
		ctxCancel:   cancel,
		delegate:    d,
		done:        make(chan struct{}),
		pollDone:    make(chan struct{}),
		storeAnswer: make(chan storeReply, 1),
	}
	close(s.pollDone) // no poll goroutine
	go s.runStore(ctx, work)
	return &Transfer{s: s}, nil
}

// runStore is run's counterpart for stored transfers, with the same ordering:
// the lock is free before the terminal event, the cancel watchdog may have
// claimed that event already, and a panicking delegate is recovered.
func (s *session) runStore(ctx context.Context, work func(context.Context, *session) (storeSummary, error)) {
	var (
		sum storeSummary
		err error
	)
	func() {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("croc panic: %v\n%s", r, debug.Stack())
			}
		}()
		sum, err = work(ctx, s)
	}()
	close(s.done)
	s.ctxCancel()
	unmarkStuck(s)
	activeMu.Unlock()
	if !s.terminal.CompareAndSwap(false, true) {
		return
	}
	defer func() {
		if r := recover(); r != nil {
			reportPanic(s, r)
		}
	}()
	if err != nil {
		s.delegate.OnError(errorJSON(err))
		return
	}
	b, _ := json.Marshal(map[string]any{"success": true, "files": sum.files, "totalSize": sum.totalSize})
	s.delegate.OnDone(string(b))
}

// answerStore hands a Respond to the stored receive waiting at its preview.
// Only the first answer counts; the channel holds one, so a second never blocks.
func (s *session) answerStore(accept bool, policy filePolicy) {
	select {
	case s.storeAnswer <- storeReply{accept: accept, policy: policy}:
	default:
	}
}

// storeCallbacks turns storeclient's callbacks into OnProgress events. They run
// on storeclient's worker goroutines, where a delegate panic would take the
// process down, so each is recovered.
func (s *session) storeCallbacks() storeclient.Callbacks {
	return storeclient.Callbacks{
		Status: func(msg string) {
			if strings.HasPrefix(msg, "Hashing ") {
				s.emitProgress(progressState{Step: "preparing"})
			}
		},
		Progress: func(p storeclient.Progress) { s.emitProgress(storeProgress(p)) },
	}
}

func (s *session) emitProgress(p progressState) {
	defer func() { recover() }() //nolint:errcheck // a delegate panic must not escape into storeclient's goroutines
	b, _ := json.Marshal(p)
	s.delegate.OnProgress(string(b))
}

// storeProgress maps storeclient's cumulative byte counts onto the progress
// payload, clamped so a count past its total cannot show more than 100%.
func storeProgress(p storeclient.Progress) progressState {
	fileSent := min(max(p.FileBytes, 0), p.FileSize)
	finished := min(max(p.TotalBytes-p.FileBytes, 0), p.TotalSize)
	return progressState{
		CurrentFile: p.FileIndex, TotalFiles: p.FileCount, FileName: p.FileName,
		FileSent: fileSent, FileSize: p.FileSize, BytesFinished: finished,
		TotalSize: p.TotalSize, Step: "transferring",
	}
}

func storeFileListJSON(m storecrypto.Manifest) string {
	files := make([]fileEntry, len(m.Files))
	for i, f := range m.Files {
		files[i] = fileEntry{Name: f.Name, Size: f.Size}
	}
	b, _ := json.Marshal(map[string]any{"files": files, "emptyFolders": 0, "totalSize": manifestTotal(m)})
	return string(b)
}

func manifestTotal(m storecrypto.Manifest) int64 {
	var total int64
	for _, f := range m.Files {
		total += f.Size
	}
	return total
}

func sizeOfFiles(paths []string) int64 {
	var total int64
	for _, p := range paths {
		if info, err := os.Lstat(p); err == nil {
			total += info.Size()
		}
	}
	return total
}

// keepBothNames renames, in place, each manifest file whose name already exists
// in dir to croc's Keep Both form ("name (1).ext"). storeclient installs with a
// rename that replaces whatever is there, so Keep Both has to be settled in the
// manifest before the download. The names are local only: the server and the
// chunk encryption never see them.
func keepBothNames(dir string, files []storecrypto.ManifestFile) {
	taken := make(map[string]bool, len(files))
	for _, f := range files {
		taken[receivefs.CollisionKey(f.Name)] = true
	}
	exists := func(name string) bool {
		_, err := os.Lstat(filepath.Join(dir, name))
		return err == nil
	}
	for i := range files {
		name := files[i].Name
		if !exists(name) {
			continue
		}
		ext := filepath.Ext(name)
		base := strings.TrimSuffix(name, ext)
		for n := 1; ; n++ {
			candidate := fmt.Sprintf("%s (%d)%s", base, n, ext)
			if !exists(candidate) && !taken[receivefs.CollisionKey(candidate)] {
				files[i].Name = candidate
				taken[receivefs.CollisionKey(candidate)] = true
				break
			}
		}
	}
}
