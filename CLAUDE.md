# CrocApp

Free, open-source native SwiftUI GUI for the "croc" file-transfer CLI. Targets iOS 26 + macOS 26. See `@docs/knowledge/project-overview.md` for goals, `docs/ARCHITECTURE.md` for system structure, `docs/GLOSSARY.md` for vocabulary.

## Layout

- `.claude/`: project Claude config, `rules/`, `skills/`, `settings.json` and `settings.local.json`.
- `.mcp.json`: project MCP servers `xcode` and `gopls` (Go semantics), both behind the `caveman-shrink` stdio proxy (compresses tool descriptions). context7 (docs) and playwright (browser, for landing/docs sites) come from plugins enabled in `.claude/settings.json` instead, never both ways at once (ADR 0024).
- `.github/`: `workflows/ci.yml` (format, Go lint/vuln/build/vet, macOS + iOS builds), `workflows/govulncheck.yml` (weekly scan, ADR 0018), `workflows/landing.yml` and `workflows/docs.yml` (Pages deploy; both publish the whole site via `scripts/assemble-site.sh`, ADR 0025); issue and PR templates route per `ISSUE_TEMPLATE/config.yml`.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`: contributor policy at repo root (ADR 0023). `CONTRIBUTING.md` publicly restates the Working Rules below; change both together.
- `.swift-format`, `.xcode-version`, `crocmobile/.golangci.yml`: tool configs. See `docs/knowledge/tooling.md` for the exact pinned versions and rationale.
- `app/`: Xcode project (SwiftUI, iOS + macOS), `CrocApp.xcodeproj`, `CrocApp/` sources, `CrocShare/` share extension, `Config/` (plists, entitlements, export options).
- `assets/`: brand art. `assets/screenshots/README.md` lists the light/dark pairs root `README.md` requires.
- `CrocKit/`: Swift package wrapping the Go engine (`CrocEngine` actor, `AsyncStream<TransferEvent>`, `crockit-verify` harness). Depends on `Croc.xcframework` (gitignored build artifact).
- `crocmobile/`: Go wrapper around croc v10.5.0, gomobile-bound into `Croc.xcframework`. `session.go` is the engine, `cmd/croctest` its CLI harness.
- `design/`: design system (tokens, component specs, SF Symbols mapping, `tokens.css` for web). Canonical for the app and web surfaces (ADR 0015). Read `design/README.md` before any visual change.
- `docs/ARCHITECTURE.md`, `docs/BUILDING.md`, `docs/GLOSSARY.md`: system map/event flow, exact toolchain versions and fresh-clone steps, and term glossary respectively. Canonical over any version number or architecture claim restated in this file.
- `docs/knowledge/`: evergreen project knowledge, see its README for which file answers what. `docs/decisions/`: ADRs, `NNNN-slug.md`. `docs/known-issues.md`: triaged defects, accepted papercuts, release blockers (check it before filing a bug as new).
- `scripts/`: build and verification harnesses (see Commands), `lib.sh` holds shared helpers, `assemble-site.sh` builds the combined Pages artifact (ADR 0025). `web/landing/`: landing page, live at crocapp.dev. `web/docs/`: user-facing docs site (Docusaurus, six locales), live at crocapp.dev/docs/. See `docs/knowledge/docs-site.md` before touching it.

## Commands

**Fresh clone builds nothing until the xcframework exists** (`CrocKit`'s binaryTarget points at a gitignored artifact, ADR 0006). Exact toolchain versions and steps: `docs/BUILDING.md`.

```bash
scripts/build-xcframework.sh    # go + gomobile → CrocKit/Croc.xcframework

# builds (run from app/)
rtk proxy xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
rtk proxy xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build

# format + lint (same commands CI runs)
xcrun swift-format format --in-place --recursive --parallel app/CrocApp app/CrocShare CrocKit/Sources
xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources
rtk proxy golangci-lint run ./...     # from crocmobile/; plain `golangci-lint` gets mangled by rtk
govulncheck ./...                     # from crocmobile/

# verification harnesses (need outbound network to the public relay and a croc CLI; scenarios detailed in docs/BUILDING.md)
scripts/verify-interop.sh
scripts/verify-app-mac.sh
scripts/verify-app-sim.sh
scripts/verify-share-sim.sh
scripts/build-devid.sh        # Developer ID archive → export → notarization pre-check

# landing page, local preview
cp design/tokens.css web/landing/ && python3 -m http.server --directory web/landing

# docs site, local preview (tokens copy runs automatically)
pnpm --dir web/docs start

# full Pages artifact (landing + docs), built locally
scripts/assemble-site.sh
```

Env: `CROC` (default `~/go/bin/croc`), `SIM` (default `iPhone 17 Pro`; list with `xcrun simctl list devices`).

Targets: `CrocApp` (`com.bakirgdev.CrocApp`), `CrocShare` (`.CrocShare`). No schemes committed; Xcode autocreates them on open.

## Working Rules

### Verify, don't assume

A green build is **not** evidence a transfer works. Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` needs the matching harness above run, output quoted. If a harness was not run, say "not verified" plainly.

### Delegate

Sessions mostly run on a stronger model, so preserve its context and session usage. Delegate any substantial task to cheaper-model subagents with clear, accurate, self-contained instructions. Act as manager and coordinator: split the work, brief each subagent, review what comes back, and correct it before it lands.

### Read before writing

Start at `docs/ARCHITECTURE.md` for the system map. `docs/knowledge/crocmobile-bridge.md` and `docs/knowledge/app-ui-architecture.md` hold the hard-won invariants (event ordering, fd0 prompt-pipe semantics, per-file sender answers, relay-address blanking, room collisions on 4-char code prefixes) that "obvious" fixes here re-break; read the relevant file before editing the engine, the bridge, or the UI state machine. Anything visual (app views, landing page, docs site) reads `design/README.md` first: tokens only, no raw hex/px; SF Symbols only in the app; system font only, never a bundled font file.

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `@.claude/rules/context7.md`), perform web search, deploy research subagent(s), or use tool search, before writing code. A small lookup beats a hallucination, doubly so for Swift/SwiftUI/Xcode 26 APIs (training data lags Apple releases) and the croc CLI (frequent new versions). Prefer semantic tools over grep where they exist: `gopls` MCP for `crocmobile/` (`go_search`, `go_symbol_references`, `go_file_context`, `go_package_api`, `go_diagnostics`), `xcode` MCP for build/test/diagnostics/simulator on the Swift side (needs the project open in Xcode, Settings > Intelligence > MCP enabled; not a substitute for `scripts/verify-*.sh`).

### Comments

Don't comment your thoughs or the obvious things. Only leave comments when really needed to explain why something is done a certain way, or to clarify non-obvious behavior. Avoid redundant comments that restate the code. If comment is needed, keep it short, clear, and relevant.

### Commit and push

Never commit or push unless told to. When asked to, do it with best practices and reason about applicable changes for the commit message.

### Docs self-heal (end of every session)

Every session ends by creating, updating, or deleting documentation so `docs/` and `CLAUDE.md` matches reality:

- Decision made: new ADR in `docs/decisions/` (next number). Decision reversed or replaced: new ADR superseding the old one, old one marked `Status: superseded by NNNN`. A fact inside an existing ADR that stopped being true: overwrite it in place, no `Amended` marker, and re-verify what it claims (`docs/decisions/README.md`).
- Durable knowledge gained: add/update file in `docs/knowledge/` and/or `CLAUDE.md`.
- Defect found and consciously not fixed: line in `docs/known-issues.md`. Defect fixed: delete its line.
- Stale or wrong doc noticed during the session: fix or delete it now.
- Genuinely nothing doc-worthy: say so explicitly before ending.

Keep docs small, dense, direct. Each `docs/` subdirectory has a README.md explaining what belongs there. Never cite `TODO.md` or a `PLAN.md` from inside `docs/` (scratch files that get deleted; a doc that points at one rots on the spot). For the same reason, do not use "Phase N" as a fact in any doc; say what the thing is, not when it was built.

### Session end report

Close every session with this, in order, no praise, no prompt recap, always in simple words (can omit or add other items):

1. **Done**: what changed, one line per file or area.
2. **Verified**: commands actually run and their result. Anything not run is listed as "not verified".
3. **Docs**: ADRs and knowledge files added, changed, deleted, or an explicit "nothing doc-worthy".
4. **Open**: known gaps, deferred work, follow-ups. Anything durable goes in `docs/known-issues.md`, not only in the report.

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
