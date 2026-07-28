# 0028. The docs site ships six locales in one build

Status: accepted
Date: 2026-07-28

## Context

CrocApp's own UI is English-only, but its documentation does not have to be, and a user deciding whether to trust a code-phrase file transfer benefits from reading about it in their own language. Docusaurus's i18n support produces every locale from one `docusaurus build` invocation, so shipping more locales is a translation-file cost, not a second build pipeline.

## Decision

- Six locales: `en` (default, canonical) plus `bs`, `de`, `es`, `fr`, `ru`.
- **One `docusaurus build` emits all of them into one static bundle.** English serves at `/docs/`, the rest at `/docs/<locale>/`. No per-locale workflow or deploy step.
- Translation files live under `web/docs/i18n/<locale>/`: `code.json` (UI strings), `docusaurus-theme-classic/{navbar,footer}.json`, `docusaurus-plugin-content-docs/current.json` (sidebar labels), and `docusaurus-plugin-content-docs/current/**` for the translated markdown itself.
- `pnpm run write-translations:all` runs `docusaurus write-translations --locale <l>` for each of the five non-English locales, appending new keys without overwriting translations already made.
- **English is authoritative.** The five non-English trees are machine-assisted drafts, each carrying a `:::warning` admonition on its index page saying so and asking for native-speaker review. Nothing gates a draft from shipping; the warning is the only signal a reader gets.
- Since the app's own UI stays English-only, translated pages keep literal UI labels (button text, screen names) in English inside backticks rather than translating them, translating a label the app does not display would mislead the reader.

## Consequences

- Five of six locales are unreviewed. A wrong or misleading machine translation is live on the site with only a warning banner between it and a reader, until someone who speaks the language reviews it.
- Adding a new user-facing page means either writing it in all six locales immediately or accepting that `write-translations:all` will flag the new strings as untranslated in the other five until someone fills them in.
- One build failing (a broken link in any locale's content) fails the whole site's deploy, per ADR 0025 and the `onBrokenLinks: throw` config, there is no per-locale deploy to fall back to.
- Locale review work has no owner or process defined yet beyond "GitHub issue," `docs/known-issues.md` tracks this as an open gap.
