# croc upgrade playbook

How to bump the pinned croc version (go.mod, currently v10.5.0). Run this as one session whenever upstream releases.

## Steps

1. **Read upstream delta**: changelog/release notes + `git diff vOLD..vNEW` of `src/croc/croc.go`, `src/croc/ctx.go`, `src/cli/cli.go`, `src/models/constants.go`, `src/utils/utils.go`. Look specifically for:
   - New callback/hook APIs for confirm prompts or output → may obsolete the fd-0 prompt pipe (ADR 0008 says the shim shrinks to nothing then)
   - `Options` struct field changes (new flags → new `crocmobile.Options` fields; renamed/removed → compile errors, good)
   - Changes to `Client` progress fields our poller reads (`TotalSent`, step bools, `FilesToTransfer`, `FilesToTransferCurrentNum`)
   - Prompt sites (`utils.GetInput` callers) added/removed — each maps to a workaround in `docs/knowledge/crocmobile-bridge.md`
   - Wire/protocol changes (major version bump = incompatible peers)
2. **Cross-check every documented workaround** in `crocmobile-bridge.md` §"croc gotchas" and ADR 0008 against the delta: for each, decide keep / delete / adapt. Delete obsolete shims — do not leave dead workarounds.
3. **Bump**: `cd crocmobile && go get github.com/schollz/croc/v10@vNEW && go mod tidy`; also `go install github.com/schollz/croc/v10@vNEW` (test CLI must match the pin).
4. **Build**: `go build ./... && go vet ./...`, then `./scripts/build-xcframework.sh`, then `cd CrocKit && swift build`, then app build both platforms.
5. **Verify**: `./scripts/verify-interop.sh` (all 9), `./scripts/verify-app-sim.sh`, `crockit-verify twice` two-transfer check. Any failure → root-cause against the upstream delta before touching wrapper semantics.
6. **Docs self-heal**: update `crocmobile-bridge.md`, `what-is-croc.md` (version header + changed facts), ADR if the bridge architecture changed.

## Notes

- Wire compat is stable within v10.x; a v11 needs both sides upgraded — coordinate app release timing with upstream adoption.
- Watch croc's README/issues for a callback-based embedder API; that is the single change that most simplifies crocmobile.
