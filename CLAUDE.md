# CrocApp

Free, open-source native SwiftUI GUI for the croc file-transfer CLI. Targets iOS 26 + macOS 26. See `@docs/knowledge/project-overview.md` for goals.

## Layout

- `app/` — Xcode project (SwiftUI, iOS + macOS): `app/CrocApp.xcodeproj`, sources `app/CrocApp/`
- `docs/knowledge/` — evergreen project knowledge
- `docs/decisions/` — ADRs, `NNNN-slug.md`
- `web/landing/`, `web/docs/` — static sites (GitHub Pages)

## Rules

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `@.claude/rules/context7.md`), web search, or tool search before writing code. A small lookup beats a hallucination. Applies doubly to Swift/SwiftUI/Xcode 26 APIs — training data lags Apple releases.

### Docs self-heal (end of every session)

Every session ends by creating, updating, or deleting documentation so `docs/` matches reality:

- Decision made or changed → new ADR in `docs/decisions/` (next number; supersede, don't rewrite old ones)
- Durable knowledge gained → add/update file in `docs/knowledge/`
- Stale or wrong doc noticed during the session → fix or delete it now
- Genuinely nothing doc-worthy → say so explicitly before ending

Keep docs small, dense, direct. Each `docs/` subdirectory has a README.md explaining what belongs there.

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
