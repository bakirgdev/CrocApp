# 0026. The docs site is user-facing only

Status: accepted
Date: 2026-07-28

## Context

`web/docs/` needed a scope before it needed content. The repository already has extensive documentation, `docs/ARCHITECTURE.md`, `docs/BUILDING.md`, `docs/GLOSSARY.md`, `docs/decisions/`, `docs/knowledge/`, `CONTRIBUTING.md`, all written for contributors and AI sessions, and none of it is what a person who just installed CrocApp needs. Mirroring that material into the Docusaurus site would mean maintaining it in two places, and the copy would rot the first time one side changed without the other.

The repository also already has a top-level `docs/` directory that means "contributor and internals documentation." Docusaurus's own convention is to put its content in a directory called `docs/`. Those two facts collide inside `web/docs/`.

## Decision

- **Content is user-facing only.** Sixteen pages: install, first transfer, sending, receiving, code phrases, power options, settings and trust, history, croc CLI interoperability, a feature matrix, a user glossary, security and privacy, troubleshooting, FAQ, and a short contribute page.
- **Contributor and internals documentation stays in the repository**, not mirrored. The site's contribute page and footer link to it with absolute GitHub URLs (`ARCHITECTURE.md`, `BUILDING.md`, `CONTRIBUTING.md`, and so on) rather than reproducing it. Those files track the code and are written for contributors and agents; a copy on the docs site would drift the moment either side changed.
- **Docusaurus content lives at `web/docs/content/`, not `web/docs/docs/`.** The preset's `docs.path` is set to `content`, avoiding a same-name collision with the repository's own `docs/` directory (which means something else entirely) while keeping `routeBasePath: '/'`, so `content/guide/sending.md` still serves at `crocapp.dev/docs/guide/sending/`.
- **The blog plugin is disabled** (`blog: false`). Release notes belong in GitHub Releases and `CHANGELOG.md`, not a second changelog surface.

## Consequences

- A contributor-facing fact (an ADR, an invariant in `docs/knowledge/`) never needs a docs-site update. Only user-facing behavior does.
- The site cannot answer "why was this built this way", only "how do I use it". That question is answered by linking out, which means the site depends on the GitHub repo staying public and those files staying at their current paths.
- `content/` as the docs root is a one-off deviation from Docusaurus's default layout. Anyone scaffolding a new page with `docusaurus-init`-style tooling has to remember the path is not `docs/`.
