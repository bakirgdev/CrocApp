# Token to web

How the tokens apply to the landing page (`web/landing`) and the docs site (`web/docs`). `swiftui.md` is the app counterpart. No values are defined here: this file says which token a web surface takes and what web does that the app does not.

## What these surfaces are

Web pages, not an app shell. Keep the Apple type scale, the colors and the 4pt grid; drop the device chrome. Both sites ship both themes and follow the OS by default. They consume `tokens.css` (never a copy, `AGENTS.md` → Mirrors and checks).

## Page fill

`--color-surface-base`, which `tokens.css` sets on `body`. Not the app's grouped fill: links are 4.94:1 on base and 4.42:1 on grouped, and a web page runs links through its prose. Cards are `--color-surface-card` with a hairline border (`components.md` → Card), because in light the two fills are the same white.

## Width

| Content | Cap |
|---|---|
| hero, full-bleed rows, screenshot galleries | `--content-max-width-wide-web` |
| default section | `--content-max-width-web` |
| paragraphs | `--content-max-width-prose-web` |
| a phone screenshot inline in docs prose | `--phone-shot-max-width-web` |

One narrow exception: an element that depicts the app (a hero screenshot) takes `--content-max-width`, because it draws the phone column. The row it sits in still takes a web cap.

## Theming

Every themed token is a `light-dark()` pair resolved by `color-scheme`. `:root` declares `light dark`, so an untouched page follows the OS; `[data-theme="light"]` and `[data-theme="dark"]` pin it.

The landing page sets `data-theme` from `localStorage` in the external, synchronous `theme-init.js` in `<head>` before first paint, accepting only `light` or `dark`; the docs site gets the same from Docusaurus. The theme toggle also rewrites `<meta name="theme-color">`, whose two literals are `--bg-base` light and dark (`#FFFFFF`, `#000000`).

## Head, images and policy

| Rule | Why |
|---|---|
| Every landing page carries the same `<meta http-equiv="Content-Security-Policy">` (`default-src 'self'`, `connect-src 'self'`, `object-src 'none'`, `base-uri 'none'`, `form-action 'none'`, `'self'` for script, style and image). No inline script, inline style or `data:` image | No hashes to maintain; a page cannot call a third party. The docs site has none (`docs/knowledge/landing-page.md`, "Content-Security-Policy") |
| Screenshots are WebP, one file per theme. Every `<img>` has `width` and `height`; the above-the-fold image takes `fetchpriority="high"`, the rest `loading="lazy"`. A themed hero image is a `<picture>` whose dark `<source>` carries `media="(prefers-color-scheme: dark)"` | No layout shift; only the variant that matches the theme downloads |
| Every landing page links `site.webmanifest`, the 96px PNG, `favicon.ico` and the apple-touch icon, and sets description, Open Graph and Twitter tags with `og.jpg`; the indexable pages (home, privacy, support) add a canonical link, `404.html` and `r/` add `noindex` | The favicon set is the app icon (`brand.md` → Favicon recipe); the docs site reuses it |
| The landing keeps `llms.txt`, `robots.txt` and `sitemap.xml` at the root | Crawler and assistant entry points (`docs/knowledge/landing-page.md`, "Crawler files") |
| The docs site's tagline, `<title>` and social image repeat the landing headline | One headline everywhere (`brand.md` → Positioning) |

## Type

Hero, section headings, card titles and leads take the web display scale through `.t-web-hero`, `.t-web-section`, `.t-web-sub`, `.t-web-lead` (on docs, Infima's heading variables point at the same tokens). Everything at body size and below stays on the app scale.

## Glass

The sticky nav is the only glass, because content scrolls under it. Everything else is `solid` (`materials.md`).

## Hover and focus

Hover is the pressed background only, inside `@media (hover: hover)` (`platforms.md` → Hover). Focus is `--shadow-focus-ring` from `tokens.css`, never restyled per component.

## Icons

Lucide, inlined as one `<symbol>` sprite referenced with `<use>`, `aria-hidden="true"`. Names, sizes and strokes are `iconography.md`'s. The docs theme draws its own few chrome glyphs (theme toggle, external-link arrow); those are the theme's.

## Docs site (Docusaurus)

`web/docs/src/css/custom.css` maps Infima's variables onto tokens, so the theme renders in our colors: the primary ladder onto the accent aliases (a `.button--primary` takes `--color-accent-solid` so its label clears AA), links on a fill wash (table cells, inline code) onto `--color-accent-text-on-tint`, grays onto fills and separators, admonitions onto the status tints (text stays primary), headings onto the web scale, and the code theme onto tokens. Nothing in it is a literal; `web/docs/src/prismTheme.ts` writes `var(--token)` strings, weight included. The mascot is the navbar mark (`brand.md` → Mascot).

## Writing direction

Logical properties everywhere: `padding-inline`, `margin-block`, `inset-inline-start`, `border-block-end`, `max-inline-size`. An RTL locale is a `dir="rtl"` away.

## The only literals web may write

| Literal | Why |
|---|---|
| breakpoint widths in a media condition | `var()` does not resolve there (`spacing-layout.md` → Breakpoints) |
| the two `theme-color` meta values, and `theme_color` / `background_color` in `site.webmanifest` | browser chrome cannot take a custom property; the manifest values must equal `--bg-base` in light, which `scripts/verify-design.sh` checks |
| `0` (any unit), `100%`, `100svh`, `1px` inside a visually-hidden utility, `90deg` rotation of a chevron | geometry, not design values |
| `50%` inside a visually-hidden utility (`clip-path: inset(50%)`) | geometry of the clip; any other `50%` (centering, `translate`) is a token or a logical-property layout |
| `12%`, `22%`, `82%` and `black` inside `color-mix()` | the Button state specs in `components.md` → Button (and the 22% status border); outside `color-mix()` every other percentage and every named color (`white`, `red`, …) is a finding |

Everything else, including component metrics, is a token (`--btn-*-web`, `--pill-*-web`, …). `scripts/verify-design.sh` enforces this over the CSS, the landing HTML and `app.js`, and `prismTheme.ts` (JS and TS files also take no numeric font weight).
