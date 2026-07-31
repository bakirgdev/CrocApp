# croc upgrade playbook

How to bump the pinned croc version (go.mod). Run this as one session whenever upstream releases.

**Pinned: v10.5.0. Latest upstream: v10.6.0 (2026-07-26). This playbook is due.**

## Steps

1. **Read upstream delta**: changelog/release notes + `git diff vOLD..vNEW` of `src/croc/croc.go`, `src/croc/ctx.go`, `src/cli/cli.go`, `src/models/constants.go`, `src/utils/utils.go`. Look specifically for:
   - New callback/hook APIs for confirm prompts or output → may obsolete the fd-0 prompt pipe (the shim shrinks to nothing then)
   - `Options` struct field changes (new flags → new `crocmobile.Options` fields; renamed/removed → compile errors, good)
   - Changes to `Client` progress fields our poller reads (`TotalSent`, step bools, `FilesToTransfer`, `FilesToTransferCurrentNum`)
   - Prompt sites (`utils.GetInput` callers) added/removed — each maps to a workaround in `docs/knowledge/crocmobile-bridge.md`
   - Wire/protocol changes (major version bump = incompatible peers)
2. **Cross-check every documented workaround** in `crocmobile-bridge.md` §"croc gotchas" against the delta: for each, decide keep / delete / adapt. Delete obsolete shims — do not leave dead workarounds.
3. **Bump**: `cd crocmobile && go get github.com/schollz/croc/v10@vNEW && go mod tidy`; also `go install github.com/schollz/croc/v10@vNEW` (test CLI must match the pin).
4. **Build**: `go build ./... && go vet ./...`, then `./scripts/build-xcframework.sh`, then `cd CrocKit && swift build`, then app build both platforms.
5. **Verify**, in this order — each one covers ground the previous does not:
   - `crockit-verify twice` — Swift layer, and the two-transfer case proves fd0/stdout/cwd/mutex restoration still composes
   - `./scripts/verify-interop.sh` — all 9 crocmobile↔CLI scenarios
   - `./scripts/verify-app-mac.sh` — both directions plus local-only, custom relay, no-compress, and both-sides-confirm; the widest coverage of the option surface
   - `./scripts/verify-app-sim.sh` — iOS simulator receive
   - `./scripts/verify-share-sim.sh` — share-extension handoff
   
   Any failure → root-cause it against the upstream delta before touching wrapper semantics.
6. **Docs self-heal**: update `crocmobile-bridge.md`, `what-is-croc.md` (version header + changed facts), and this file's pinned-version line.

## Notes

- Wire compat is stable within v10.x; a v11 needs both sides upgraded — coordinate app release timing with upstream adoption.
- Watch croc's README/issues for a callback-based embedder API; that is the single change that most simplifies crocmobile.
