# Landing page

Operational knowledge for `web/landing/`, the plain HTML site at `https://crocapp.dev/`. The Docusaurus site under `/docs` is `docs-site.md`.

## What is in it

| Path | Purpose |
|---|---|
| `index.html`, `styles.css`, `app.js` | The landing page. `app.js` only enhances (the theme toggle, and keeping the hero `<picture>` sources in step with a pinned theme); the page reads with JavaScript off. The FAQ is native `<details>` |
| `theme-init.js` | Loaded synchronously in the `<head>` of every page: sets `data-theme` from `localStorage` before first paint. External so the CSP needs no hash |
| `r/index.html`, `r/receive.js` | The receive-link page behind `https://crocapp.dev/r/#<code>`. It offers to open the app, get the app or receive in a browser. `receive.js` parses the fragment and fills the links |
| `privacy/`, `support/` | Static pages |
| `.well-known/apple-app-site-association` | Universal links for `/r/*`, for both app IDs (`com.bakirgdev.CrocApp` and `.direct`, each with the team prefix) |
| `.well-known/security.txt` | The address `SECURITY.md` hands out |
| `llms.txt`, `robots.txt`, `sitemap.xml` | Crawler and assistant files. `robots.txt` lists this sitemap and the docs one |
| `CNAME`, `404.html` | Custom domain and not-found page |
| `web/landing/assets/img/` | `mascot-web.webp`, the store badges (SVG), `og.jpg` (the social card, also used by the docs site), `favicon/` (the app-icon based favicon set and `site.webmanifest`, also used by the docs site) and `screenshots/{mac,iphone}/` (the hero shots, WebP, a light and dark file each) |

## How it ships

`scripts/assemble-site.sh` copies `web/landing/` to the site root, copies `design/tokens.css` beside it (the only copy that ships; `index.html` links `tokens.css`, which is never committed under `web/landing/`) and puts the built Docusaurus site under `/docs`. `.github/workflows/github-pages.yml` runs it on a push to `main` and deploys. The pre-merge build is the `site build` job in `ci.yml`. One deploy always ships both surfaces: `docs-site.md`, "One workflow publishes both surfaces".

The script fails the build unless these hold:

- `CNAME`, `index.html` and `404.html` exist at the root.
- `.well-known/security.txt` exists. It is a dot-path, so it reaches production only while `github-pages.yml` keeps `include-hidden-files: true`.
- `.well-known/apple-app-site-association` exists and lists both app IDs.
- `r/index.html` sets `<meta name="referrer" content="no-referrer">` and loads no remote `script`, `link`, `img` or `iframe`. The code lives in the URL fragment, so the page must not leak it. Its one network hop is a link the user clicks, to getcroc.com.

## Content-Security-Policy

Every landing page (`index.html`, `privacy/`, `support/`, `r/`, `404.html`) carries the same `<meta http-equiv="Content-Security-Policy">`: `default-src 'self'` plus `script-src`, `style-src`, `img-src` and `connect-src` of `'self'`, and `object-src`, `base-uri` and `form-action` at `'none'`. `connect-src` is `'self'` rather than `'none'` only so Lighthouse's robots.txt audit can fetch the file; the pages make no requests of their own. GitHub Pages cannot send headers, so a meta tag is all there is (`frame-ancestors` is ignored there). The docs site has no CSP.

The policy forbids inline script and style, `data:` images and any remote host, and nothing on the pages needs them (JSON-LD is data, not script). To add a resource, load it from a file in the same origin. If a page truly needs another origin, widen the one directive for it in every page that loads it, and record why in `THREAT-MODEL.md`, "Privacy". A violation shows only in the browser console, so load each changed page once with the console open: `scripts/assemble-site.sh` does not check the policy.

## Images

Screenshots are WebP, one file per theme, and the hero uses `<picture>` with a `<source media="(prefers-color-scheme: dark)" data-theme-source>` so only the variant that matches the OS downloads. A manual theme pin cannot reach a `<source>` before parse, so `app.js` rewrites that `media` to `all` or `not all` on load and on toggle. Trade-off: a pin that disagrees with the OS fetches the OS variant first, then the pinned one (`known-issues.md`, "Landing page"). Every image has `width` and `height`; the Mac hero image has `fetchpriority="high"` and the rest are `loading="lazy"`. `scripts/capture-screenshots.sh --copy-web` writes the WebP files and needs `cwebp` (`brew install webp`).

## Head

Every landing page links `site.webmanifest`, the 96px PNG, `favicon.ico` and the apple-touch icon (the set is the app icon, `design/brand.md`, "Favicon recipe"; the docs site reuses it), and sets description, Open Graph and Twitter tags with `og.jpg`. The indexable pages (home, privacy, support) add a canonical link, and `404.html` and `r/` add `noindex`. The two `<meta name="theme-color">` literals are `--bg-base` light and dark, and the theme toggle rewrites them. The docs site's tagline, `<title>` and social image repeat the landing headline.

## Crawler files

- `llms.txt` is hand-written to the llmstxt.org shape: an H1, a blockquote, then H2 sections of `- [Title](url): note` lines. It links every docs page, so a docs page added, renamed or removed is edited here too.
- `sitemap.xml` lists the landing, support and privacy pages with a `lastmod`. Update the date when a page's content changes. The docs sitemap is generated.
- `robots.txt` lists both sitemaps.

## Rules

- Visual and copy rules are `design/principles.md`, `design/implementation.md`, "Web", and `design/voice.md`. Colors come from the tokens, with no raw color in the page or its stylesheet (`scripts/verify-design.sh` checks).
- Run `scripts/verify-design.sh` after touching `styles.css` or the page, and `scripts/verify-docs.sh` after touching a path this file names.

## Hand-maintained

Nothing checks these. They are listed in `docs/known-issues.md`, "Landing page":

- Per release: `softwareVersion` in the JSON-LD block of `index.html`, the release status in `llms.txt`, and the "available now" and "coming soon" copy and store cards in `index.html` (`RELEASING.md`, "Each release"). `datePublished` stays the first public release.
- The store badges stay unlinked until the apps are on the App Store.
- `security.txt` has an `Expires` field to renew.
- The AASA `/r/*` component is wider than the one page that exists.
