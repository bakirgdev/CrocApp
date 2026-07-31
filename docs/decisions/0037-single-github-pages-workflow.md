# 0037. One workflow builds and deploys GitHub Pages

Status: accepted
Date: 2026-07-31

## Context

ADR 0025 put `landing.yml` and `docs.yml` side by side: two workflow files, each with its own trigger paths, both calling `scripts/assemble-site.sh` and sharing the `github-pages` concurrency group so their deploys queue instead of racing. That avoided the artifact-clobbering problem, but the two files still duplicate every step (checkout, pnpm setup, cache, assemble, verify CNAME, upload, deploy, release-lock-on-cancel) and drift independently whenever one gets edited and the other does not.

Since both workflows always call the same script and always publish the same `_site/`, having two files bought path-based naming and nothing else — every actual difference other than the `paths:` list was accidental drift.

## Decision

Replace `landing.yml` and `docs.yml` with one file, `.github/workflows/github-pages.yml`. It triggers on the union of both surfaces' paths (`web/landing/**`, `web/docs/**`, `design/tokens.css`, `scripts/assemble-site.sh`, its own path) and runs the same steps ADR 0025 already established once instead of twice. `concurrency: { group: github-pages, cancel-in-progress: false }` and the `if: cancelled()` lock-release step carry over unchanged.

`site-preview.yml` is renamed `github-pages-preview.yml` to match, with its own `paths:` and concurrency group renamed the same way. It still runs `assemble-site.sh` on `pull_request` and never deploys.

## Consequences

- One file to edit, one place the assembly steps can drift from `scripts/assemble-site.sh`'s expectations.
- Behavior is unchanged from ADR 0025: any push touching either surface still rebuilds and redeploys both, because `assemble-site.sh` always produces the whole site regardless of which path fired the trigger.
- A broken Docusaurus build still fails a landing-only push, same as before — that trade-off was ADR 0025's, not new here.
