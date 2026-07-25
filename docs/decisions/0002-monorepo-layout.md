# 0002. Monorepo layout

Status: accepted
Date: 2026-07-21

## Context

Project spans a native app, a landing page, a docs site, and project documentation. Sole developer, AI-first workflow: sessions work best when all context lives in one repo.

## Decision

Single public repo holds everything:

- `app/` — Xcode project
- `CrocKit/` — Swift package wrapping the Go engine (ADR 0006)
- `crocmobile/` — Go wrapper, gomobile-bound (ADR 0006)
- `scripts/` — build + verification harnesses
- `assets/` — brand art
- `design/` — design system, canonical for app and web (ADR 0015)
- `web/landing/`, `web/docs/` — static sites (GitHub Pages, ADR 0019)
- `docs/` — knowledge + ADRs
- `.claude/` — AI tooling config, rules, skills

## Consequences

- One clone gives any session (human or AI) full context; cross-cutting changes are atomic.
- Mixed toolchains in one repo; every workflow path-filters so a commit only pays for what it touched (ADR 0014, ADR 0018).
