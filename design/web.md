# Web

How the tokens apply to the landing page and the docs site. `swiftui.md` is the app counterpart. No values are defined here — this file says which token a web surface takes, and what web has to do that the app does not.

## What these surfaces are

Web pages, not an app shell. Keep the Apple type scale, the colors and the 4pt grid; drop the device chrome. Both sites ship both themes and follow the OS preference by default.

They consume `tokens.css`, which is why the marketing surface and the product look like one thing. Never edit a copy — `design/tokens.css` is the only committed one (`CLAUDE.md` → Three mirrors).

## Page fill

Page is `--color-surface-base`, **not** the app's `--color-surface-grouped`. Link text is 4.94:1 on base and 4.42:1 on grouped, and a web page runs links through its prose. Cards carry the tonal step instead.

## Width

`--content-max-width` (480px) is the app's phone column and is not a page container. Use the web caps in `spacing-layout.md` → Web layout:

| Content | Cap |
|---|---|
| hero, full-bleed rows, screenshot galleries | `--content-max-width-wide` |
| default section | `--content-max-width-web` |
| paragraphs | `--content-max-width-prose` |

**One exception, and it is narrow:** an element that *depicts* the app — the landing page's CSS-built Send screen, a docs screenshot frame — takes `--content-max-width`, because it is drawing the phone column rather than laying out a page. The row it sits in still takes a web cap. If the element is not a picture of the app, this does not apply.

## Theming

Every token is a `light-dark()` pair resolved by `color-scheme`. `:root` declares `light dark`, so an untouched page follows the OS; `[data-theme="dark"]` / `[data-theme="light"]` pin `color-scheme` and win in both directions.

A consuming page sets `data-theme` from a small inline script **before first paint** — that is the whole integration, and it is what avoids a flash of the wrong theme. Nothing else is required, and no second `prefers-color-scheme` block of token values is needed.

## Type

Hero, section headings, card titles and leads take the web display scale (`typography.md` → Web display scale), via `.t-web-hero` `.t-web-section` `.t-web-sub` `.t-web-lead`. Everything at body size and below stays on the app scale — the two scales meet at lead size deliberately, so a web page and an app screen read as the same voice.

## Glass

Glass needs something to blur. On a flat single-color background it reads as a slightly tinted rectangle, so prefer the `solid` material on these pages unless there is real imagery behind. The CSS `backdrop-filter` recipe in `materials-motion.md` is an approximation of `.glassEffect()`, never a target of its own.

## Hover

Hover exists here, because a web page has a pointer. It applies the element's pressed background and nothing else: no scale, no lift, no shadow change. Nothing may be discoverable only on hover. Full rule in `platforms.md` → Hover, states table in `components.md` → States.

## Icons

Lucide, because SF Symbols cannot ship to the web. The page inlines one `<symbol>` sprite and references it with `<use>` rather than repeating path data at every call site. Always `aria-hidden="true"`. Names, sizes and stroke tokens are `iconography.md`'s.

## Breakpoints and layers

Three breakpoints, two stacking layers, both tabled in `spacing-layout.md`. Breakpoint values are literals in the stylesheet because a custom property does not resolve inside a media condition — that table is the only place they are defined.

## Writing direction

Logical properties everywhere: `padding-inline`, `margin-block`, `inset-inline-start`, `border-start-start-radius`. Nothing here is laid out in physical directions, so an RTL locale is a `dir="rtl"` away.

## The only literals web may write

Rule 1 is otherwise absolute — no raw hex, px or duration.

| Literal | Why |
|---|---|
| breakpoint widths in a media condition | `var()` does not resolve there |
| `<meta name="theme-color">` | browser chrome, cannot take a custom property |
| component metrics | already tokenized as `--btn-*`, `--pill-*`, `--row-min-file`, `--nav-height-web`, `--grid-min-card`; use those, not the numbers behind them |
