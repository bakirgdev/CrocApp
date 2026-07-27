# Spacing, radius, layout

4pt grid throughout. Every gap, pad and inset resolves to one of these steps.

## Spacing scale

| Token | Value |
|---|---|
| `--space-1` | 2px |
| `--space-2` | 4px |
| `--space-3` | 8px |
| `--space-4` | 12px |
| `--space-5` | 16px |
| `--space-6` | 20px |
| `--space-7` | 24px |
| `--space-8` | 32px |
| `--space-9` | 40px |
| `--space-10` | 48px |
| `--space-11` | 64px |

Common usage: screen horizontal padding `--space-5`, card padding `--space-6`, stack gap between unrelated blocks `--space-6`/`--space-7`, gap inside a row `--space-3`/`--space-4`.

## Radii

iOS 26 continuous corners. **Concentric rule: outer radius = inner radius + the gap between them.** A 12px-padded card at `--radius-lg` (20) holds children at ~8 — round down to `--radius-xs`/`--radius-sm` rather than inventing a value.

| Token | Value | Applies to |
|---|---|---|
| `--radius-xs` | 6px | inner chips, nested fills |
| `--radius-sm` | 10px | segmented control track, small tinted buttons |
| `--radius-md` | 14px | fields, list rows, banners, QR frame |
| `--radius-lg` | 20px | glass cards / panels |
| `--radius-xl` | 28px | sheets, large containers |
| `--radius-2xl` | 36px | full-screen glass surfaces |
| `--radius-capsule` | 999px | prominent buttons, badges, progress bars, switch |

On Apple platforms use `.rect(cornerRadius:style: .continuous)` — never the default circular style, it visibly mismatches system chrome.

## Layout caps

| Token | Value | Meaning |
|---|---|---|
| `--content-max-width` | 480px | content column cap; centered on wider viewports |
| `--sheet-max-width` | 540px | sheet / modal cap |

macOS keeps the same column cap; only density, chrome and input affordances change (no sidebar, drop hint in the window, full-window "Drop to send" glass overlay).

## Web layout (landing + docs only)

Never used by the app. `--content-max-width` is a phone-width column; a marketing or docs page needs a page-width container, a readable prose measure, and rhythm that scales with the viewport. Both ends of every `clamp()` sit on the 4pt grid.

| Token | Value | Meaning |
|---|---|---|
| `--content-max-width-wide` | 1280px | hero, full-bleed rows, screenshot galleries |
| `--content-max-width-web` | 1080px | default section container |
| `--content-max-width-prose` | 680px | paragraph measure (~75ch) |
| `--gutter-web` | `clamp(20px, 5vw, 48px)` | page horizontal padding |
| `--section-pad-web` | `clamp(64px, 9vw, 112px)` | vertical gap between sections |
| `--stack-web` | `clamp(32px, 4vw, 48px)` | gap between blocks inside a section |
| `--store-badge-height` | 40px | Apple's stated minimum for a supplied App Store badge |
| `--step-marker-size` | 32px | numbered step marker in a How-it-works list |
| `--mascot-size-web` | 64px | mascot in a footer or empty state |
| `--stars-slot-min` | 28px | reserved width for the repo star count in a nav |

### Breakpoints

Three, and no more without a reason written down. **These are literals by necessity** — a custom property does not resolve inside a media condition, so the numbers appear in the stylesheet and this table is the only place they are defined. `rem`, not `px`, so they respond to the user's font size.

| Width | What changes |
|---|---|
| `30rem` | Nav collapses the GitHub label to its glyph and count |
| `48rem` | Nav keeps only its primary anchor; the rest drop |
| `64rem` | Hero splits into copy + mockup columns |

### Stacking order

Two layers, both tokenized. Anything that wants a third needs a reason first.

| Token | Value | Layer |
|---|---|---|
| `--z-nav` | 2 | sticky bar, above page content |
| `--z-skip-link` | 3 | above the bar it exists to jump past |

## Control sizing

| Token | Value | Meaning |
|---|---|---|
| `--control-height-lg` | 50px | `.controlSize(.large)` buttons, code field |
| `--control-height-md` | 38px | medium buttons, inline paste button |
| `--control-height-sm` | 30px | small buttons, segment min height |
| `--hit-target-min` | 44px | HIG minimum tap target — floor for anything interactive |
| `--icon-size-sm` | 17px | inline / row icons |
| `--icon-size-md` | 22px | default icon |
| `--icon-size-lg` | 28px | prominent icons |

Row heights that are not tokenized (they are component constants, see `components.md`): settings row min 52, file row min 48, sheet header min 52, switch 51×31, settings row icon tile 29×29 at radius 7, StatusBlock glyph circle 64, TrustBadge full glyph circle 34, QR frame default 168.

## Component metrics tokenized for web (landing + docs only)

Same numbers `components.md` already specifies, promoted to tokens because the web side forbids raw px and a component constant has to be *nameable* to be usable there. SwiftUI keeps them as constants inside the component — **do not use these tokens in the app.**

| Token | Value | From |
|---|---|---|
| `--btn-pad-x-lg` / `-md` / `-sm` | 22px / 16px / 12px | Button size table |
| `--btn-gap-lg` / `-md` / `-sm` | 8px / 6px / 5px | Button size table |
| `--btn-icon-lg` / `-md` / `-sm` | 20px / 18px / 15px | Button size table, `iconography.md` |
| `--row-min-file` | 48px | FileRow min height |
| `--progress-height` | 6px | ProgressBar track and fill |
| `--pill-pad-block` | 5px | TrustBadge pill |
| `--pill-pad-inline-start` / `-end` | 9px / 11px | TrustBadge pill — asymmetric, the glyph sits tighter to the leading edge |
| `--pill-icon-size` | 14px | TrustBadge pill |
| `--nav-height-web` | 56px | landing sticky nav; clears `--hit-target-min` 44 with `--space-2` breathing room either side |
| `--grid-min-card` | 232px | `auto-fit` column floor: 4-up at 1080, 2-up at 768, 1-up at 375. Largest 4pt-grid value that still fits four columns in `--content-max-width-web` (984 usable − 3×16 gap = 936; 936 ÷ 4 = 234) |

`--btn-pad-x-md`, `--btn-pad-x-sm` and `--btn-gap-lg` are aliases of `--space-5`, `--space-4` and `--space-3`. They exist so a call site reads as button geometry rather than as an arbitrary grid step.

## Borders

| Token | Value |
|---|---|
| `--border-hairline` | 1px |
| `--border-hairline-half` | 0.5px |

Grouped lists separate rows with `inset 0 -0.5px 0 var(--color-separator)` (a half-pixel inset shadow, not a border) so the row corners stay clean; the last row omits it.

Focus is a 4px halo (`--shadow-focus-ring`), not a border — see `materials-motion.md`.

## Writing direction

Use logical properties everywhere: `padding-inline`, `margin-block`, `inset-inline-start`, `border-start-start-radius`. The specs in `components.md` name a leading and a trailing edge, never a left and a right. Nothing in this system is laid out in physical directions, so an RTL locale is a `dir="rtl"` away rather than a rewrite.
