# CrocApp

Free, open-source native SwiftUI GUI for the croc file-transfer CLI. Targets iOS 26 + macOS 26. See `@docs/knowledge/project-overview.md` for goals.

## Layout

- `.claude/` — project Claude config: `rules/`, `skills/`, `settings.json` & `settings.local.json`, etc.
- `.mcp.json` — project MCP servers: `context7` (docs), `xcode` (`xcrun mcpbridge`), `gopls` (Go semantics; launched via `$(go env GOPATH)/bin/gopls` since `~/go/bin` is usually off PATH)
- `.github/` — GitHub config: issue/PR templates, workflows, etc.
- `app/` — Xcode project (SwiftUI, iOS + macOS): `app/CrocApp.xcodeproj`, app sources `app/CrocApp/`, share extension `app/CrocShare/`, plists + entitlements + export options `app/Config/`
- `assets/` — brand art: `CrocAppIcon.icon` source, banner, mascot, etc.
- `CrocKit/` — Swift package wrapping the Go engine: `CrocEngine` actor + `AsyncStream<TransferEvent>`, plus `crockit-verify` executable harness. Depends on `Croc.xcframework` (gitignored build artifact)
- `crocmobile/` — Go wrapper around croc v10.5.0, gomobile-bound into `Croc.xcframework`. `session.go` is the engine; `cmd/croctest` is its CLI harness
- `docs/knowledge/` — evergreen project knowledge
- `docs/decisions/` — ADRs, `NNNN-slug.md`
- `scripts/` — build + machine-verification harnesses (see Commands)
- `web/landing/`, `web/docs/` — static sites (GitHub Pages)

## Commands

**Fresh clone builds nothing until the xcframework exists** — `CrocKit`'s binaryTarget points at a gitignored artifact (ADR 0006).

```bash
scripts/build-xcframework.sh    # go + gomobile → CrocKit/Croc.xcframework. Needs Go ≥1.25, Xcode 26+

# builds (run from app/)
rtk proxy xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
rtk proxy xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build

# verification — all need outbound network (public relay) and a croc CLI
scripts/verify-interop.sh     # 9 scenarios, crocmobile ↔ croc CLI (both directions, decline, cancel, relay, LAN)
scripts/verify-app-mac.sh     # macOS app both directions + --local sandboxed relay listener
scripts/verify-app-sim.sh     # iOS simulator, CLI → app via --auto-receive
scripts/verify-share-sim.sh   # share-extension handoff (App Group staging) → CLI receive
scripts/build-devid.sh        # Developer ID archive → export → notarization pre-check
```

Env: `CROC` (default `~/go/bin/croc`), `SIM` (default `iPhone 17 Pro`; list with `xcrun simctl list devices`).

Targets: `CrocApp` (`com.bakirgdev.CrocApp`), `CrocShare` (`.CrocShare`). No schemes committed — Xcode autocreates them.

## Working Rules

### Verify, don't assume

A green build is **not** evidence a transfer works. Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` → run the matching harness above and quote its output. If a harness was not run, say "not verified" plainly.

### Read before writing

`docs/knowledge/crocmobile-bridge.md` and `docs/knowledge/app-ui-architecture.md` hold the hard-won invariants: event ordering, fd0 prompt-pipe semantics, per-file sender answers, relay-address blanking, room collisions on 4-char code prefixes. Most "obvious" fixes here re-break one of them. Read the relevant file before editing the engine, the bridge, or the UI state machine.

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `@.claude/rules/context7.md`), perform web search, deploy research subagent(s) or use tool(s) search before writing code. A small lookup beats a hallucination. Applies doubly to Swift/SwiftUI/Xcode 26 APIs (training data lags Apple releases) and croc CLI (new versions often).

Prefer semantic tools over grep where they exist: `gopls` MCP for `crocmobile/` (`go_search`, `go_symbol_references`, `go_file_context`, `go_package_api`, `go_diagnostics`), `xcode` MCP for build/test/diagnostics/simulator on the Swift side. `xcode` requires the project open in Xcode and Settings > Intelligence > MCP enabled; it is **not** a substitute for `scripts/verify-*.sh`.

### Commit and push

Never commit or push unless told to. When asked to, do it with best practices and reason about applicable changes for the commit message. 

### Docs self-heal (end of every session)

Every session ends by creating, updating, or deleting documentation so `docs/` and `CLAUDE.md` matches reality:

- Decision made or changed → new ADR in `docs/decisions/` (next number; supersede, don't rewrite old ones)
- Durable knowledge gained → add/update file in `docs/knowledge/` and/or `CLAUDE.md`
- Stale or wrong doc noticed during the session → fix or delete it now
- Genuinely nothing doc-worthy → say so explicitly before ending

Keep docs small, dense, direct. Each `docs/` subdirectory has a README.md explaining what belongs there.

### Session end report

Close every session with this, in order, no praise and no prompt recap:

1. **Done** — what changed, one line per file or area
2. **Verified** — commands actually run and their result. Anything not run is listed as "not verified"
3. **Docs** — ADRs and knowledge files added / changed / deleted, or an explicit "nothing doc-worthy"
4. **Open** — known gaps, deferred work, follow-ups worth a `TODO.md` line
5. **Simple** - simplified version of changes and learning opportunities

Mark speculation as speculation.

<!-- rtk-instructions v2 -->
## RTK (Rust Token Killer) - Token-Optimized Commands

## Golden rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

### Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->
