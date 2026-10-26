# croc upgrade playbook

How to bump the pinned croc version in `crocmobile/go.mod`. Run it as one session whenever upstream releases.

**Pinned: v11.5.5.**

## Steps

1. **Read the upstream delta.** Read the changelog and release notes, then `git diff vOLD..vNEW` of these paths: `src/croc/croc.go`, `src/croc/ctx.go`, `src/cli/cli.go`, `src/models/constants.go`, `src/utils/utils.go`, `src/codephrase`, `src/publicrelay`, `src/pakekey`. Look for:
   - New callback or hook APIs for confirm prompts or output. They may make the fd 0 prompt pipe obsolete (the shim would shrink to nothing).
   - `Options` struct changes. New flags need new `crocmobile.Options` fields. Renamed or removed fields fail to compile, which is good.
   - Changes to the `Client` progress fields the poller reads: `TotalSent`, the step booleans, `FilesToTransfer`, `FilesToTransferCurrentNum`.
   - Prompt sites (`utils.GetInputContext` callers) added or removed. Each one maps to a workaround in `crocmobile-bridge.md`.
   - Wire or protocol changes. A major version bump means incompatible peers.
2. **Cross-check every documented workaround.** Take each one in `crocmobile-bridge.md`, "croc v11.5.5 gotchas (verified against source)", and decide keep, delete or adapt against the delta. Delete obsolete shims; do not leave dead workarounds. Rename that heading to the new version in step 6.
3. **Bump.**
   - Run `cd crocmobile && go get github.com/schollz/croc/v11@vNEW && go mod tidy`. A new major changes the `/vN` import path everywhere.
   - Then run `brew upgrade croc` so the test CLI matches the pin (`brew install croc` on a fresh machine). The harnesses default `CROC` to `${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc`.
4. **Build.** Run `go build ./... && go vet ./...` in `crocmobile/` with `GOFLAGS=-tags=croc_no_tailcat` (`BUILDING.md`, "Format and lint"), then `./scripts/build-xcframework.sh`, then `cd CrocKit && swift build`, then build the app for both platforms.
5. **Verify**, in this order. Each one covers ground the previous one does not (`BUILDING.md`, "Verification harnesses" has the commands):
   - `crockit-verify twice`: the Swift layer. The two-transfer case proves the fd 0, stdout, cwd and mutex restoration still composes.
   - `PUBLIC_POOL=1 ./scripts/verify-interop.sh`: all 15 crocmobile to CLI scenarios, including the public relay pool (scenario 11), which only runs with `PUBLIC_POOL=1`.
   - `PUBLIC_POOL=1 ./scripts/verify-app-mac.sh`: the 12 macOS app scenarios. This is the widest coverage of the option surface.
   - `PUBLIC_POOL=1 ./scripts/verify-app-sim.sh`: iOS simulator receive and the share-extension handoff.

   `PUBLIC_POOL=1` sends through the public relays, which is where a croc upgrade can change relay selection or the code-to-relay mapping. A pool relay rate-limits, so wait a minute between harnesses, and a failure counts as a regression only after its log says so (`known-issues.md`, "Harnesses"). Run the same three without `PUBLIC_POOL` as well: that is what CI runs for interop and what finds a local-relay regression.

   Any failure: find the root cause against the upstream delta before touching wrapper semantics.
6. **Update docs.**
   - Run `git grep -n "v11.5.5"` (the old version string) and update every hit. The hits include this file's "Pinned" line, `what-is-croc.md` (the version header and any changed facts), `crocmobile-bridge.md` (the version in the layers diagram, the "croc v11.5.5 gotchas" heading and the Advanced options text), `known-issues.md`, and comments in `crocmobile/`.
   - Also check any other file the grep turns up, and update facts that changed even where the version string is absent.
   - Check the names in `known-issues.md` and `docs/GLOSSARY.md` that the delta touched.
   - Run `scripts/verify-docs.sh`.

## Notes

- A new major needs both sides upgraded. v10 and v11 peers cannot complete a transfer: v11 rejects a PAKE message that lacks protocol version 2 (`pakekey.ProtocolVersion`), and v10.5.0's message type has no version field.
- The peers often never meet, because the room derivation and the default relay differ. So `peerVersion` fires only on a shared room.
- `~/go/bin/croc` (v10.5.0, pinned in `scripts/croc-v10.version`) is kept only as `CROC_V10`, for the v10-peer scenario. If it is first on `PATH`, plain `croc` runs v10, so call Homebrew's `croc` by full path (`known-issues.md`, "Harnesses").
- Coordinate app release timing with upstream adoption.
- Watch croc's README and issues for a callback-based embedder API. That is the single change that would most simplify crocmobile.
