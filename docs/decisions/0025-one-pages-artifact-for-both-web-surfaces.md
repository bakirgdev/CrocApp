# 0025. One Pages artifact serves both web surfaces

Status: accepted
Date: 2026-07-28

## Context

ADR 0019 gave the landing page its own workflow on the theory that a docs site arriving later would get a second, independent one. That theory does not survive contact with how GitHub Pages actually works: Pages serves one site per repository, and `actions/deploy-pages` replaces the entire published artifact on every deploy. Two independent workflows, each uploading its own `_site/`, would not coexist, they would take turns deleting each other's output. Whichever ran last would win until the other ran again.

The docs site (`web/docs/`, Docusaurus) has now landed and needs the same domain, `crocapp.dev`, at `/docs/`.

## Decision

`scripts/assemble-site.sh` builds the complete Pages artifact in one place: `web/landing/` copied in verbatim at `/`, `design/tokens.css` copied to `/tokens.css` (per ADR 0015), and the Docusaurus build output copied to `/docs/`. Both `.github/workflows/landing.yml` and `.github/workflows/docs.yml` call that one script and upload the result.

- The two workflows differ only in trigger paths: `landing.yml` fires on `web/landing/**`, `docs.yml` fires on `web/docs/**`, and both also fire on `design/tokens.css`, `scripts/assemble-site.sh`, and their own workflow file.
- Both share `concurrency: { group: github-pages, cancel-in-progress: false }`, the same group name regardless of which workflow queued the run. This is what makes two workflows safe: they queue behind each other instead of racing to overwrite.
- Both check out with `fetch-depth: 0` (Docusaurus `showLastUpdateTime` reads per-file git history) and run `corepack enable pnpm` before the assembly script, which shells out to `pnpm --dir web/docs build`.
- ADR 0019's cancellation-lock release step (`if: cancelled()`, `POST .../pages/deployments/:sha/cancel`) is unchanged and now lives in both workflow files.

This supersedes ADR 0019's "one workflow per site" decision. Its other reasoning (assemble don't publish in place, assert CNAME survived, queue don't cancel, release the lock on cancellation) still holds and is folded into `assemble-site.sh` and both workflows.

## Consequences

- A landing-only edit now also rebuilds and redeploys the docs site (a `pnpm install` plus a Docusaurus build), even though nothing under `web/docs/` changed. Accepted: the alternative is the two-workflow race this ADR rules out.
- `assemble-site.sh` is the one place that knows the artifact shape. Either workflow drifting from it independently is now impossible, they call the same script.
- A broken Docusaurus build fails `landing.yml` too, not just `docs.yml`, since `landing.yml` also runs `assemble-site.sh` end to end. A docs build error can block a pure landing-page deploy.
- `web/landing/` and `web/docs/build/` are still not independently deployable; whatever serves either has to run the assembly script, same as ADR 0019 already established for the landing directory alone.
