# Landing page

Operational knowledge for `web/landing/`, the plain HTML site at `https://crocapp.dev/`. The Docusaurus site under `/docs` is `docs-site.md`.

## What is in it

| Path | Purpose |
|---|---|
| `index.html`, `styles.css`, `app.js` | The landing page. `app.js` only enhances (theme toggle, FAQ, nav); the page reads with JavaScript off |
| `r/index.html` | The receive-link page behind `https://crocapp.dev/r/#<code>`. It offers to open the app, get the app or receive in a browser |
| `privacy/`, `support/` | Static pages |
| `.well-known/apple-app-site-association` | Universal links for `/r/*`, for both app IDs (`com.bakirgdev.CrocApp` and `.direct`, each with the team prefix) |
| `.well-known/security.txt` | The address `SECURITY.md` hands out |
| `llms.txt`, `robots.txt`, `sitemap.xml` | Crawler and assistant files. `robots.txt` lists this sitemap and the docs one |
| `CNAME`, `404.html` | Custom domain and not-found page |
| `web/landing/assets/img/` | Store badges, favicons and the web manifest |

## How it ships

`scripts/assemble-site.sh` copies `web/landing/` to the site root, copies `design/tokens.css` beside it (the only copy that ships; `index.html` links `tokens.css`, which is never committed under `web/landing/`) and puts the built Docusaurus site under `/docs`. `.github/workflows/github-pages.yml` runs it on a pull request (build only) and on a push to `main` (build and deploy). One deploy always ships both surfaces: `docs-site.md`, "One workflow publishes both surfaces".

The script fails the build unless these hold:

- `CNAME`, `index.html` and `404.html` exist at the root.
- `.well-known/security.txt` exists. It is a dot-path, so it reaches production only while `github-pages.yml` keeps `include-hidden-files: true`.
- `.well-known/apple-app-site-association` exists and lists both app IDs.
- `r/index.html` sets `<meta name="referrer" content="no-referrer">` and loads no remote `script`, `link`, `img` or `iframe`. The code lives in the URL fragment, so the page must not leak it. Its one network hop is a link the user clicks, to getcroc.com.

## Rules

- Visual and copy rules are `design/web.md` and `design/content.md`. Colors, spacing and type come from the tokens, with no literals in the page or its stylesheet (`scripts/verify-design.sh` checks).
- Run `scripts/verify-design.sh` after touching `styles.css` or the page, and `scripts/verify-docs.sh` after touching a path this file names.

## Hand-maintained

Nothing checks these. They are listed in `docs/known-issues.md`, "Landing page":

- `llms.txt` release status and the store cards (version, channels, "coming soon" wording) change on every release.
- The store badges stay unlinked until the apps are on the App Store.
- `security.txt` has an `Expires` field to renew.
- The AASA `/r/*` component is wider than the one page that exists.
