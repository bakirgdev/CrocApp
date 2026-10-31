# Docs site

Operational knowledge for `web/docs/` (Docusaurus 3.10.2, pnpm 12, TypeScript 7).

## Local development

Node 26 (`web/docs/.nvmrc`) and pnpm 12 are required (`tooling.md`).

```bash
pnpm --dir web/docs install
pnpm --dir web/docs start
```

`start` runs the `tokens` script first (`cp ../../design/tokens.css src/css/tokens.css`), then `docusaurus start`. `tokens.css` is gitignored, same pattern as `web/landing/tokens.css`: edit `design/tokens.css`, never `web/docs/src/css/tokens.css` directly, the copy is overwritten on every `start` or `build`.

The same `tokens` script copies `web/landing/assets/img/mascot-web.webp` to `static/img/mascot.webp` (gitignored), the navbar logo. It is the one web derivative of the mascot (`design/brand.md`, "Mascot"); never commit a second copy.

The docs site keeps no icon or social-card file of its own. `docusaurus.config.ts` points the favicon, the apple-touch icon, the web manifest and the social image (`og.jpg`) at the landing copies under `web/landing/assets/img/` through absolute `https://crocapp.dev/assets/img/...` URLs (a site-relative URL would get the `/docs/` base prefixed). Replace those files on the landing side only. The mascot is the exception: it stays a local copy so `docusaurus start` does not depend on the live site.

To build the full Pages artifact (both surfaces, what CI publishes) locally:

```bash
scripts/assemble-site.sh          # writes ./_site/, landing at /, docs at /docs/
```

## Crawler files

`web/docs/static/llms.txt` is the hand-written docs index (llmstxt.org shape), served at `/docs/llms.txt`. A page added, renamed or removed is edited there and in the landing `llms.txt` (`landing-page.md`, "Crawler files"). There is no `llms-full.txt`: Docusaurus does not generate one, and the only route is a third-party plugin, a new dependency this repo has not adopted. The sitemap at `/docs/sitemap.xml` is generated and listed in the landing `robots.txt`.

## Content and styling rules

- Page copy is bound by `design/voice.md` (terminology, capitalization, the approved security claims) and `design/brand.md`. Headings and sidebar titles are sentence case; app controls are quoted in bold, Title Case, exactly as the app spells them.
- Theme styling lives in `web/docs/src/css/custom.css`, mapped onto `design/tokens.css` with no raw colors (`design/implementation.md`, "Docs site"). The code theme is `src/prismTheme.ts`, the same token mapping. The navbar collapses at Docusaurus's own 996px breakpoint, not ours, so do not set `display` on a `.navbar__item` outside a `min-width: 997px` media query.
- Screenshots come from `scripts/capture-screenshots.sh --copy-web` into `web/docs/screenshots/{mac,iphone}/` as WebP (not under `static/`, so Docusaurus hashes them). A page references them by relative path as a light and dark pair on one line, each with a `#gh-light-mode-only` or `#gh-dark-mode-only` fragment: `![Send screen on macOS](../../screenshots/mac/send-files-light.webp#gh-light-mode-only)`. `custom.css` shows the one that matches the theme toggle. Every image carries `width` and `height`, so the page does not shift while it loads. The alt text must not contain an apostrophe. The phone-width cap in `custom.css` keys off the alt text, so an iPhone shot's alt must say "on iOS".

## Adding a page

New file under `web/docs/content/` (not `docs/`, that name is taken by the repository's own contributor docs). Frontmatter needs `title`, `description`, and `sidebar_position`. The sidebar is hand-written in `web/docs/sidebars.ts`, grouped by task rather than by directory, so a new page is added there by doc id (its path under `content/` without `.md`). A page missing from `sidebars.ts` has no sidebar. The groups have no landing page of their own, so no thin `/category/` pages exist. `routeBasePath: '/'`, so `content/guide/foo.md` serves at `/docs/guide/foo/`.

The docs site is English only: `docusaurus.config.ts` configures the single locale `en`. It has a home page and a sidebar of guide pages.

Moving or deleting a page also needs a redirect, or the old URL, which search engines and the GitHub issue forms still hold, answers 404. The `redirects` array of the `@docusaurus/plugin-client-redirects` entry in `docusaurus.config.ts` maps each old path to its new one (the plugin writes a small HTML stub at the old path). Add the entry in the same change.

## Versions

The site has one version and `docusaurus.config.ts` configures none, so there is no version dropdown and no `versioned_docs/`. `web/docs/package.json` carries the release version, bumped with `app/Config/Version.xcconfig`. When a later release changes behavior that an older version's readers still need described, run `pnpm --dir web/docs run docusaurus docs:version <version>` and add the dropdown to the navbar then. Release notes are not a docs page: the navbar and footer link to GitHub Releases.

## Broken links fail the build

`onBrokenLinks`, `onBrokenAnchors`, `markdown.hooks.onBrokenMarkdownLinks`, and `markdown.hooks.onBrokenMarkdownImages` are all `throw`. A bad internal link or anchor fails `pnpm run build`, which fails `scripts/assemble-site.sh`, which fails the `site build` job and `github-pages.yml`. The `site build` job in `ci.yml` runs the same assembly (and `tsc`) on every pull request that touches the site files, so a broken link is caught before merge.

## One workflow publishes both surfaces

`github-pages.yml` runs on a push to `main` only: it deploys. The pre-merge build is the `site build` job in `ci.yml`. It calls `scripts/assemble-site.sh` and uploads the whole `_site/`. Editing only `web/docs/**` still rebuilds the Docusaurus site and re-copies `web/landing/` verbatim, and editing only `web/landing/**` does the reverse. GitHub Pages replaces the entire artifact on every deploy, so a single workflow always ships both. The workflow triggers on `web/landing/**`, `web/docs/**`, `design/tokens.css`, `scripts/assemble-site.sh` and its own file.

## What `assemble-site.sh` asserts

The script fails the build unless the landing files and the receive-link page are in place. The list is in `landing-page.md`, "How it ships". It also requires `index.html` under the `docs` folder.

## Traps

- **Frontmatter values containing a colon must be quoted.** `description: Fixes for X: stalled transfers` breaks the build with "bad indentation of a mapping entry". Quote the whole value: `description: "Fixes for X: stalled transfers"`. Several pages under `content/` already need this, check before adding a colon to any frontmatter field.
- **`showLastUpdateTime` renders nothing for a file that is not yet committed.** It reads git history per file (`fetch-depth: 0` in `github-pages.yml` and the `site build` job makes this work in CI); a new page with only uncommitted local edits shows no "last updated" line until it lands in a commit. This is not a bug, only confusing while drafting.
