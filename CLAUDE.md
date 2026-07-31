# CrocApp

Free, open-source native SwiftUI GUI for the "croc" file-transfer CLI. Targets iOS 26 + macOS 26. See `@docs/knowledge/project-overview.md` for goals, `docs/ARCHITECTURE.md` for system structure, `docs/GLOSSARY.md` for vocabulary.

## Working Rules

### Verify, don't assume

A green build is **not** evidence a transfer works. Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` needs the matching harness above run, output quoted. If a harness was not run, say "not verified" plainly.

### Delegate

Sessions mostly run on a stronger model, so preserve its context and session usage. Delegate any substantial task to cheaper-model subagents with clear, accurate, self-contained instructions. Act as manager and coordinator: split the work, brief each subagent, review what comes back, and correct it before it lands.

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `@.claude/rules/context7.md`), perform web search, deploy research subagent(s), or use tool search, before writing code. A small lookup beats a hallucination, doubly so for Swift/SwiftUI/Xcode 26 APIs (training data lags Apple releases) and the croc CLI (frequent new versions). Prefer semantic tools over grep where they exist: `gopls` MCP for `crocmobile/` (`go_search`, `go_symbol_references`, `go_file_context`, `go_package_api`, `go_diagnostics`), `xcode` MCP for build/test/diagnostics/simulator on the Swift side (needs the project open in Xcode, Settings > Intelligence > MCP enabled; not a substitute for `scripts/verify-*.sh`).

### Comments

Don't comment your thoughs or the obvious things. Only leave comments when really needed to explain why something is done a certain way, or to clarify non-obvious behavior. Avoid redundant comments that restate the code. If comment is needed, keep it short, clear, and relevant.

### Commit and push

Never commit or push unless told to. When asked to, do it with best practices and reason about applicable changes for the commit message.

### Session end report

Close every session with this, in order, no praise, no prompt recap, always in simple words (can omit or add other items):

1. **Done**: what changed, one line per file or area.
2. **Verified**: commands actually run and their result. Anything not run is listed as "not verified".
3. **Docs**: knowledge files added, changed, deleted, or an explicit "nothing doc-worthy".
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
