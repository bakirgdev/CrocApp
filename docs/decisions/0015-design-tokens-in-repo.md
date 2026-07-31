# 0015. Design tokens live in `design/` as the single source of truth

Status: accepted
Date: 2026-07-25

## Context

The redesign was produced in Claude Design (ADR 0005 keeps the app native SwiftUI; the design project is spec, not shipping code). Its output is a design system — colors, type scale, spacing, materials, motion, thirteen components — plus 26 screen files, all of which live behind a claude.ai login. Three consumers need those values: the SwiftUI app, the landing page, and the docs site. None of them can link to a login-gated project.

Contributors and future Claude Code sessions also need the values without a Claude Design account.

## Decision

Extract the design system into `design/` in this repo, as markdown, and treat it as canonical.

- `design/*.md` — the token set and component specs, written for humans and AI sessions. Canonical.
- `design/tokens.css` — hand-maintained mirror of the same values for web consumers. Changing a value means changing both; nothing generates one from the other.
- Web consumers never keep their own copy. `web/landing/tokens.css` is gitignored and produced by copying `design/tokens.css` in — by `github-pages.yml` at deploy (ADR 0037), and by hand for local preview. One committed copy exists, so a stale token under `web/` is not a state the repo can reach.
- The Claude Design project stays the *visual* reference (screen layouts, renders). It is not a build dependency and is not required to work on the repo.
- Two owner rules are binding on the app: **SF Symbols only** and **system font only**. The design system's Lucide glyphs and self-hosted SF Pro OTFs exist solely because a web canvas cannot use Apple system resources.

## Consequences

- The app, landing page and docs share one vocabulary; a token change is one PR touching one directory.
- Drift risk between `design/*.md` and `design/tokens.css` is real and accepted — the alternative (a build step) is not worth it at this size. A mismatch is a bug in the same directory, not a mystery.
- Re-generating in Claude Design later does not automatically update the repo. Whoever regenerates re-extracts, in that session.
- Contrast facts are recorded with the tokens: the brand accent `#1E9E6A` is 3.41:1 on white, so it is a fill/large-text color in the light theme, not a body-text color. Light theme is the constrained one and gets checked first.
- The restyle stayed cosmetic: adopting the tokens (ADR 0029) changed no accept-gate flow, phase state machine, or prompt-pipe event handling (ADR 0008, 0009).
