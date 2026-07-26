# CrocApp

Free, open-source native SwiftUI GUI for the "croc" file-transfer CLI. Currently targets iOS 26 + macOS 26. See `@docs/knowledge/project-overview.md` for goals.

## Layout

- `.claude/` — project Claude config: `rules/`, `skills/`, `settings.json` & `settings.local.json`, etc.
- `.mcp.json` — project MCP servers: `context7` (docs), `xcode`, `gopls` (Go semantics).
- `.github/` — `workflows/ci.yml` (format, Go lint/vuln/build/vet, macOS + iOS builds), `workflows/govulncheck.yml` (weekly scan, ADR 0018), `workflows/landing.yml` (Pages deploy, ADR 0019), `FUNDING.yml` (donations config for GitHub repo page, ignore this).
- `.swift-format` — swift-format config. `.xcode-version` — Xcode baseline. `crocmobile/.golangci.yml` — Go lint config. See `@docs/knowledge/tooling.md`.
- `app/` — Xcode project (SwiftUI, iOS + macOS): `app/CrocApp.xcodeproj`, app sources `app/CrocApp/`, share extension `app/CrocShare/`, plists + entitlements + export options `app/Config/`.
- `assets/` — brand art: `CrocAppIcon.icon` source, banner, mascot, and other brand files.
- `CrocKit/` — Swift package wrapping the Go engine: `CrocEngine` actor + `AsyncStream<TransferEvent>`, plus `crockit-verify` executable harness. Depends on `Croc.xcframework` (gitignored build artifact).
- `crocmobile/` — Go wrapper around croc v10.5.0, gomobile-bound into `Croc.xcframework`. `session.go` is the engine; `cmd/croctest` is its CLI harness.
- `design/` — design system: color/type/spacing/material/motion tokens, component specs, SF Symbols mapping, SwiftUI translation, `tokens.css` for web. Canonical for the app itself and the landing/docs sites (ADR 0015)
- `docs/knowledge/` — evergreen project knowledge (see its README for which file answers what).
- `docs/decisions/` — ADRs, `NNNN-slug.md`.
- `docs/known-issues.md` — triaged defects, accepted papercuts, release blockers. Check it before reporting a bug as new.
- `scripts/` — build + machine-verification harnesses (see Commands); `lib.sh` holds their shared helpers.
- `web/landing/` — landing page, live at crocapp.dev.
- `web/docs/` — docs site (not built yet).

## Commands

**Fresh clone builds nothing until the xcframework exists** — `CrocKit`'s binaryTarget points at a gitignored artifact (ADR 0006).

```bash
scripts/build-xcframework.sh    # go + gomobile → CrocKit/Croc.xcframework. Needs Go ≥1.26.5 (go.mod pin), Xcode 26+

# builds (run from app/)
rtk proxy xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
rtk proxy xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build

# format + lint (same commands CI runs)
xcrun swift-format format --in-place --recursive --parallel app/CrocApp app/CrocShare CrocKit/Sources
xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources
rtk proxy golangci-lint run ./...     # from crocmobile/; plain `golangci-lint` gets mangled by rtk
govulncheck ./...                     # from crocmobile/

# verification — all need outbound network (public relay) and a croc CLI
scripts/verify-interop.sh     # 9 scenarios, crocmobile ↔ croc CLI (both directions, decline, cancel, relay, LAN)
scripts/verify-app-mac.sh     # macOS app, 6 directions: both ways + --local, custom relay, --no-compress, --ask
scripts/verify-app-sim.sh     # iOS simulator, CLI → app via --auto-receive
scripts/verify-share-sim.sh   # share-extension handoff (App Group staging) → CLI receive
scripts/build-devid.sh        # Developer ID archive → export → notarization pre-check

# landing page, local preview
cp design/tokens.css web/landing/ && python3 -m http.server --directory web/landing
```

Env: `CROC` (default `~/go/bin/croc`), `SIM` (default `iPhone 17 Pro`; list with `xcrun simctl list devices`).

Targets: `CrocApp` (`com.bakirgdev.CrocApp`), `CrocShare` (`.CrocShare`). No schemes committed — Xcode autocreates them.

## Working Rules

### Verify, don't assume

A green build is **not** evidence a transfer works. Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` → run the matching harness above and quote its output. If a harness was not run, say "not verified" plainly.

### Read before writing

`docs/knowledge/crocmobile-bridge.md` and `docs/knowledge/app-ui-architecture.md` hold the hard-won invariants: event ordering, fd0 prompt-pipe semantics, per-file sender answers, relay-address blanking, room collisions on 4-char code prefixes. Most "obvious" fixes here re-break one of them. Read the relevant file before editing the engine, the bridge, or the UI state machine.

Anything visual — app views, landing page, docs site — reads `design/README.md` first. Tokens only, no raw hex/px; SF Symbols only in the app; system font only, never a bundled font file.

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `@.claude/rules/context7.md`), perform web search, deploy research subagent(s) or use tool(s) search before writing code. A small lookup beats a hallucination. Applies doubly to Swift/SwiftUI/Xcode 26 APIs (training data lags Apple releases) and croc CLI (new versions often).

Prefer semantic tools over grep where they exist: `gopls` MCP for `crocmobile/` (`go_search`, `go_symbol_references`, `go_file_context`, `go_package_api`, `go_diagnostics`), `xcode` MCP for build/test/diagnostics/simulator on the Swift side. `xcode` requires the project open in Xcode and Settings > Intelligence > MCP enabled; it is **not** a substitute for `scripts/verify-*.sh`.

### Commit and push

Never commit or push unless told to. When asked to, do it with best practices and reason about applicable changes for the commit message. 

### Docs self-heal (end of every session)

Every session ends by creating, updating, or deleting documentation so `docs/` and `CLAUDE.md` matches reality:

- Decision made → new ADR in `docs/decisions/` (next number). Decision reversed or replaced → new ADR superseding the old one, old one marked `Status: superseded by NNNN`. A fact inside an existing ADR that stopped being true → overwrite it in place, no `Amended` marker, and re-verify what it claims (`docs/decisions/README.md`)
- Durable knowledge gained → add/update file in `docs/knowledge/` and/or `CLAUDE.md`
- Defect found and consciously not fixed → line in `docs/known-issues.md`. Defect fixed → delete its line
- Stale or wrong doc noticed during the session → fix or delete it now
- Genuinely nothing doc-worthy → say so explicitly before ending

Keep docs small, dense, direct. Each `docs/` subdirectory has a README.md explaining what belongs there. Never cite `TODO.md` or a `PLAN.md` from inside `docs/` — those are scratch files that get deleted, and a doc that points at one rots on the spot. For the same reason, do not use "Phase N" as a fact in any doc; say what the thing is, not when it was built.

### Session end report

Close every session with this, in order, no praise and no prompt recap, always in simple words, guide template is below (can omit or add other):

1. **Done** — what changed, one line per file or area
2. **Verified** — commands actually run and their result. Anything not run is listed as "not verified"
3. **Docs** — ADRs and knowledge files added / changed / deleted, or an explicit "nothing doc-worthy"
4. **Open** — known gaps, deferred work, follow-ups. Anything durable goes in `docs/known-issues.md`, not only in the report

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
