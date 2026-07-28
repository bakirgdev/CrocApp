# 0027. Docs versions are cut on tagged releases, not on every change

Status: accepted
Date: 2026-07-28

## Context

Docusaurus can snapshot the current docs tree into `versioned_docs/` and keep serving old versions alongside the new one. Cutting a snapshot on every change would mean editing two copies of every page for the rest of the project's life, for a product that has not shipped a single tagged release yet. Docusaurus's own guidance is to version only when necessary, since it duplicates every file and adds build time.

`CHANGELOG.md` cannot drive a versioning decision today: it holds three unpopulated placeholder stubs, and the repository has zero git tags. There is nothing yet to snapshot against.

## Decision

- `docusaurus.config.ts` sets `lastVersion: 'current'` with `versions: { current: { label: '0.9.9' } }`. The docs tree as it exists right now is labeled 0.9.9, the version this repository is presently at; there is no separate unlabeled "Next" sitting on top of a duplicate.
- No `versioned_docs/`, `versioned_sidebars/`, or `versions.json` exists yet. Nothing is duplicated.
- **The trigger for the first snapshot is a tagged release that changes user-facing behavior**, not every patch or every merge to main. When 1.0.0 tags, run `pnpm run docusaurus docs:version 0.9.9` to freeze the pre-1.0 docs before editing `content/` for the new release.

## Consequences

- The navbar's `docsVersionDropdown` renders nothing while only one version exists, Docusaurus hides it below two versions. No version control is visible until the first cut happens.
- Until the first tag, "0.9.9" in the navbar label is the only version signal on the site; it is not wired to git tags or `CHANGELOG.md` and has to be bumped by hand if the label goes stale before 1.0.0 ships.
- Cutting a version later is a one-time manual step, not automated in CI. Forgetting it after a 1.0.0 tag means the site keeps looking pre-release with no visible version history.
