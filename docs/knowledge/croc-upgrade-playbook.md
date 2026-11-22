# croc upgrade playbook

How to bump the pinned croc version in `crocmobile/go.mod`. The update rule (what to read, how fast to take and ship) is in `RELEASING.md`, "croc updates". Dependabot opens the croc PR on day 3 for a minor and day 1 for a patch (`.github/dependabot.yml`). Run the playbook as one session per bump.

**The pin is in `crocmobile/go.mod`.** The progress of a batch of small files rests on how croc counts bundle bytes in `TotalSent` (`crocmobile-bridge.md`, "Small-file bundles"). Check each release for a change to that counting or to bundle file order, both of which `progressSnapshot` relies on.

## Steps

1. **Read the upstream delta.** Read the changelog and release notes, then `git diff vOLD..vNEW` of these paths: `src/croc/croc.go`, `src/croc/ctx.go`, `src/cli/cli.go`, `src/models/constants.go`, `src/utils/utils.go`, `src/codephrase`, `src/publicrelay`, `src/pakekey`. Look for:
   - New callback or hook APIs for output. One could replace the `os.Stdout` capture of a text receive.
   - `Options` struct changes. New flags need new `crocmobile.Options` fields. Renamed or removed fields fail to compile, which is good.
   - Changes to the `Client` progress fields the poller reads: `TotalSent`, the step booleans, `FilesToTransfer`, `FilesToTransferCurrentNum`, where `TotalSent` is reset or added to (`croc.go`, `bundle.go`), and how `bundle.Next` orders a bundle's files (`src/bundle`).
   - Questions added, removed or changed: `Question` kinds and fields, and `c.answer` call sites (`src/croc/prompt.go`, `croc.go`). A `utils.GetInputContext` read that bypasses `Options.Prompt` would block a transfer. `session.prompt` answers each kind (`crocmobile-bridge.md`, "File policy").
   - Wire or protocol changes. A major version bump means incompatible peers.
2. **Cross-check every documented workaround.** Take each one in `crocmobile-bridge.md`, "croc 11 gotchas (verified against source)", and decide keep, delete or adapt against the delta. Delete obsolete shims; do not leave dead workarounds. Rename that heading in step 6 if the major changed.
3. **Bump.**
   - Run `cd crocmobile && go get github.com/schollz/croc/v11@vNEW && go mod tidy`. A new major changes the `/vN` import path everywhere.
   - Then run `brew upgrade croc` so the test CLI matches the pin (`brew install croc` on a fresh machine). The harnesses default `CROC` to `${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc`.
4. **Build.** Run `go build ./... && go vet ./...` in `crocmobile/` with `GOFLAGS=-tags=croc_no_tailcat` (`BUILDING.md`, "Format and lint"), then `./scripts/build-xcframework.sh`, then `cd CrocKit && swift build`, then build the app for both platforms.
5. **Verify**, in this order. Each one covers ground the previous one does not (`BUILDING.md`, "Verification harnesses" has the commands):
   - `crockit-verify twice`: the Swift layer. The two-transfer case proves the stdout, cwd and mutex restoration still composes.
   - `PUBLIC_POOL=1 ./scripts/verify-interop.sh`: every crocmobile to CLI scenario, including the public relay pool (scenario 11), which only runs with `PUBLIC_POOL=1`.
   - `PUBLIC_POOL=1 ./scripts/verify-app-mac.sh`: the macOS app scenarios. This is the widest coverage of the option surface.
   - `PUBLIC_POOL=1 ./scripts/verify-app-sim.sh`: iOS simulator receive and the share-extension handoff.

   `PUBLIC_POOL=1` sends through the public relays, which is where a croc upgrade can change relay selection or the code-to-relay mapping. A pool relay rate-limits, so wait a minute between harnesses, and a failure counts as a regression only after its log says so. Run the same three without `PUBLIC_POOL` as well: that is what CI runs for interop and what finds a local-relay regression.

   Any failure: find the root cause against the upstream delta before touching wrapper semantics.
6. **Update docs.**
   - Run `git grep -n "11.6.6"` (the old version string) and update every hit: `what-is-croc.md` (the version header and any changed facts), `web/docs/content/reference/croc-cli-interop.md`, and comments in `crocmobile/` and `scripts/`. Other docs say "croc 11" and need the version only when the major changes.
   - Update facts that changed even where the version string is absent.
   - Check the names in `docs/GLOSSARY.md` that the delta touched.
   - Run `scripts/verify-docs.sh`.

## Notes

- A new major needs both sides upgraded. v10 and v11 peers cannot complete a transfer: v11 rejects a PAKE message that lacks protocol version 2 (`pakekey.ProtocolVersion`), and v10's message type (through v10.7.0) has no version field.
- A major also needs the relay image in `relay/compose.yml` bumped by hand: Dependabot ignores majors there, because a major can change the protocol or the relay pool.
- The peers often never meet, because the room derivation and the default relay differ. So `peerVersion` fires only on a shared room.
- `~/go/bin/croc` (the v10 release pinned in `scripts/croc-v10.version`) is kept only as `CROC_V10`, for the v10-peer scenario. If it is first on `PATH`, plain `croc` runs v10, so call Homebrew's `croc` by full path.
- Coordinate app release timing with upstream adoption.
- Watch croc's README and issues for a callback-based embedder API. That is the single change that would most simplify crocmobile.
