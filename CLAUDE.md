# CrocApp

Free, open-source native SwiftUI GUI for the croc file-transfer CLI. Targets iOS 26 + macOS 26. See `docs/knowledge/project-overview.md` for goals.

## Layout

- `CrocApp/` — Xcode project (SwiftUI, iOS + macOS)
- `docs/knowledge/` — evergreen project knowledge
- `docs/decisions/` — ADRs, `NNNN-slug.md`
- `web/landing/`, `web/docs/` — static sites (GitHub Pages)

## Rules

### Look up, don't guess

When unsure about any API, library, tool, or platform behavior: query the context7 MCP (see `.claude/rules/context7.md`), web search, or tool search before writing code. A small lookup beats a hallucination. Applies doubly to Swift/SwiftUI/Xcode 26 APIs — training data lags Apple releases.

### Docs self-heal (end of every session)

Every session ends by creating, updating, or deleting documentation so `docs/` matches reality:

- Decision made or changed → new ADR in `docs/decisions/` (next number; supersede, don't rewrite old ones)
- Durable knowledge gained → add/update file in `docs/knowledge/`
- Stale or wrong doc noticed during the session → fix or delete it now
- Genuinely nothing doc-worthy → say so explicitly before ending

Keep docs small, dense, direct. Each `docs/` subdirectory has a README.md explaining what belongs there.
