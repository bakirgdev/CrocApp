# 0002. Monorepo layout

Status: accepted
Date: 2026-07-21

## Context

Project spans a native app, a landing page, a docs site, and project documentation. Sole developer, AI-first workflow: sessions work best when all context lives in one repo.

## Decision

Single public repo holds everything:

- `CrocApp/` — Xcode project
- `web/landing/`, `web/docs/` — static sites (GitHub Pages)
- `docs/` — knowledge + ADRs
- `.claude/` — AI tooling config, rules, skills

## Consequences

- One clone gives any session (human or AI) full context; cross-cutting changes are atomic.
- Mixed toolchains in one repo; CI must path-filter to avoid running everything on every push.
