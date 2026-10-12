# croc upgrade playbook

How to bump the pinned croc version (go.mod). Run this as one session whenever upstream releases.

**Pinned: v11.5.4.**

## Steps

1. **Read upstream delta**: changelog/release notes + `git diff vOLD..vNEW` of `src/croc/croc.go`, `src/croc/ctx.go`, `src/cli/cli.go`, `src/models/constants.go`, `src/utils/utils.go`, `src/codephrase`, `src/publicrelay`, `src/pakekey`. Look specifically for:
   - New callback/hook APIs for confirm prompts or output → may obsolete the fd-0 prompt pipe (the shim shrinks to nothing then)
   - `Options` struct field changes (new flags → new `crocmobile.Options` fields; renamed/removed → compile errors, good)
   - Changes to `Client` progress fields our poller reads (`TotalSent`, step bools, `FilesToTransfer`, `FilesToTransferCurrentNum`)
   - Prompt sites (`utils.GetInputContext` callers) added/removed — each maps to a workaround in `docs/knowledge/crocmobile-bridge.md`
   - Wire/protocol changes (major version bump = incompatible peers)
2. **Cross-check every documented workaround** in `crocmobile-bridge.md` §"croc v11.5.4 gotchas" (rename the heading to the new version) against the delta: for each, decide keep / delete / adapt. Delete obsolete shims — do not leave dead workarounds.
3. **Bump**: `cd crocmobile && go get github.com/schollz/croc/v11@vNEW && go mod tidy` (a new major changes the `/vN` import path everywhere); then `brew upgrade croc` so the test CLI matches the pin (`brew install croc` on a fresh machine). The harnesses default `CROC` to `${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc`.
4. **Build**: `go build ./... && go vet ./...`, then `./scripts/build-xcframework.sh`, then `cd CrocKit && swift build`, then app build both platforms.
5. **Verify**, in this order — each one covers ground the previous does not:
   - `crockit-verify twice` — Swift layer, and the two-transfer case proves fd0/stdout/cwd/mutex restoration still composes
   - `./scripts/verify-interop.sh` — all 10 crocmobile↔CLI scenarios
   - `./scripts/verify-app-mac.sh` — both directions plus local-only, custom relay, no-compress, and both-sides-confirm; the widest coverage of the option surface
   - `./scripts/verify-app-sim.sh` — iOS simulator receive
   - `./scripts/verify-share-sim.sh` — share-extension handoff
   
   Any failure → root-cause it against the upstream delta before touching wrapper semantics.
6. **Docs self-heal**: update `crocmobile-bridge.md`, `what-is-croc.md` (version header + changed facts), and this file's pinned-version line.

## Notes

- A new major needs both sides upgraded. v10 and v11 peers cannot complete a transfer: v11 rejects a PAKE message that lacks protocol version 2 (`pakekey.ProtocolVersion`), and v10.5.0's message type has no version field. `~/go/bin/croc` v10.5.0 is kept only as `CROC_V10` for the v10-peer message test. Coordinate app release timing with upstream adoption.
- Watch croc's README/issues for a callback-based embedder API; that is the single change that most simplifies crocmobile.
