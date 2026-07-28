# 0019. The landing site deploys from `web/` with tokens assembled in, one workflow per site

Status: superseded by 0025
Date: 2026-07-26

## Context

The landing page is static and lives at `web/landing/`, but it is not deployable as-is: ADR 0015 makes `design/tokens.css` the only committed copy of the token mirror, so the directory Pages would publish is missing a stylesheet the page depends on. Something has to join the two.

The first workflow was a generic `pages.yml`. A docs site is coming to `web/docs/`, and a single Pages workflow serving two sites would either redeploy both when one changes, or grow conditionals to avoid it.

GitHub Pages also has a deployment model that does not behave like a normal job: `actions/deploy-pages` takes an environment lock on `github-pages`, and cancelling a run mid-deploy leaves that lock held. The next push then queues behind a deployment that will never finish.

## Decision

- **One workflow per site.** `.github/workflows/landing.yml` deploys the landing page and triggers only on `web/**`, `design/tokens.css`, and itself. A future `docs.yml` gets the same shape. `pages.yml` is gone.
- **Assemble, do not publish in place.** The job copies `web/landing/.` into `_site/`, then copies `design/tokens.css` to `_site/tokens.css`. `web/landing/tokens.css` stays gitignored; performing the identical copy locally (`cp design/tokens.css web/landing/`) makes what is served in development what deploys.
- **Assert the custom domain survived.** `test -s _site/CNAME` after assembly. `crocapp.dev` is configured by a `CNAME` file in the published artifact, and an assembly step that drops it silently unbinds the domain — a failure that presents as "the site is fine" on `*.github.io` while the real URL breaks.
- **`concurrency: { group: landing-pages, cancel-in-progress: false }`.** Deploys queue rather than cancel each other, because a cancelled deploy is what strands the lock.
- **Release the lock on cancellation.** An `if: cancelled()` step calls `POST /repos/:repo/pages/deployments/:sha/cancel`, `|| true` so cleanup never fails the run. Cancellation still happens — manually, or on branch deletion — and this makes it self-healing instead of a manual unstick.

## Consequences

- A token edit deploys the site. `design/tokens.css` is on the landing trigger paths precisely because the deployed CSS comes from outside `web/`; leaving it off would ship a stale palette.
- Two path allowlists now exist with different owners (`ci.yml` for code, `landing.yml` for web). Neither covers `docs/` or `.claude/`, which is intended — those change constantly and build nothing.
- `web/landing/` is not independently deployable. Pointing any other host at that directory serves a page with no tokens. Whatever does the serving does the copy.
- Queued deploys mean a rapid series of pushes to `web/` deploys each in turn rather than only the last. Cheap at this size, and it keeps the lock predictable.
- The site is public on every push to `main` with no preview environment. PR previews for `web/` are still to build, and are a precondition for the branch-protection rules planned at v0.9.9.
