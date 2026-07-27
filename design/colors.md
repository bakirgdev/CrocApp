# Colors

Apple system color model (iOS 26 / macOS 26) plus a croc-green brand scale. Base palette holds literal values; **semantic aliases are what you consume**. Light theme on `:root`, dark under `[data-theme="dark"]`.

## Brand — croc green

Theme-independent literals. The accent alias swaps which step it points at.

| Token | Hex | Use |
|---|---|---|
| `--green-50` | `#E8F7F0` | lightest wash |
| `--green-100` | `#C9ECDC` | |
| `--green-200` | `#97DBBD` | |
| `--green-300` | `#57C598` | |
| `--green-400` | `#2DC585` | **dark-mode accent** |
| `--green-500` | `#22B074` | dark-mode pressed |
| `--green-600` | `#1E9E6A` | **light-mode accent (brand color)** |
| `--green-700` | `#178055` | light-mode pressed; small accent text |
| `--green-800` | `#116243` | |
| `--green-900` | `#0C4A33` | |

`#05271A` is the dark-theme on-accent ink (label drawn on top of `--green-400`).

## Apple system semantics

| Token | Light | Dark |
|---|---|---|
| `--sys-green` | `#34C759` | `#30D158` |
| `--sys-orange` | `#FF9500` | `#FF9F0A` |
| `--sys-red` | `#FF3B30` | `#FF453A` |
| `--sys-blue` | `#007AFF` | `#0A84FF` |

## Labels, fills, separators

| Token | Light | Dark |
|---|---|---|
| `--ink` | `#000000` | `#FFFFFF` |
| `--paper` | `#FFFFFF` | `#000000` |
| `--label-1` | `rgba(0,0,0,1)` | `rgba(255,255,255,1)` |
| `--label-2` | `rgba(60,60,67,0.60)` | `rgba(235,235,245,0.60)` |
| `--label-2-web` | `rgba(60,60,67,0.75)` | `rgba(235,235,245,0.60)` |
| `--label-3` | `rgba(60,60,67,0.30)` | `rgba(235,235,245,0.30)` |
| `--label-4` | `rgba(60,60,67,0.18)` | `rgba(235,235,245,0.16)` |
| `--separator` | `rgba(60,60,67,0.29)` | `rgba(84,84,88,0.65)` |
| `--separator-opaque` | `#C6C6C8` | `#38383A` |
| `--fill-1` | `rgba(120,120,128,0.20)` | `rgba(120,120,128,0.36)` |
| `--fill-2` | `rgba(120,120,128,0.16)` | `rgba(120,120,128,0.32)` |
| `--fill-3` | `rgba(118,118,128,0.12)` | `rgba(118,118,128,0.24)` |
| `--fill-4` | `rgba(116,116,128,0.08)` | `rgba(118,118,128,0.18)` |

## Backgrounds

| Token | Light | Dark | Apple equivalent |
|---|---|---|---|
| `--bg-base` | `#FFFFFF` | `#000000` | systemBackground |
| `--bg-secondary` | `#F2F2F7` | `#1C1C1E` | secondarySystemBackground |
| `--bg-tertiary` | `#FFFFFF` | `#2C2C2E` | tertiarySystemBackground |
| `--bg-grouped` | `#F2F2F7` | `#000000` | systemGroupedBackground |
| `--bg-grouped-elevated` | `#FFFFFF` | `#1C1C1E` | secondarySystemGroupedBackground |

Page default is `--bg-grouped`; cards sit on `--bg-grouped-elevated`.

## Glass fills

Pair each with the matching `--blur-*` and `--glass-saturate` (see `materials-motion.md`).

| Token | Light | Dark |
|---|---|---|
| `--glass-thin` | `rgba(255,255,255,0.55)` | `rgba(30,30,32,0.55)` |
| `--glass-regular` | `rgba(255,255,255,0.72)` | `rgba(28,28,30,0.68)` |
| `--glass-thick` | `rgba(255,255,255,0.86)` | `rgba(28,28,30,0.86)` |
| `--glass-tint-accent` | `rgba(30,158,106,0.12)` | `rgba(45,197,133,0.16)` |
| `--glass-border` | `rgba(255,255,255,0.60)` | `rgba(255,255,255,0.14)` |
| `--glass-highlight` | `rgba(255,255,255,0.75)` | `rgba(255,255,255,0.10)` |

## Semantic aliases — consume these

| Alias | Light | Dark |
|---|---|---|
| `--color-accent` | `--green-600` | `--green-400` |
| `--color-accent-pressed` | `--green-700` | `--green-500` |
| `--color-accent-text` | `--green-700` | `--green-400` |
| `--color-accent-text-on-tint` | `--green-800` | `--green-400` |
| `--color-accent-tint` | `--glass-tint-accent` | `--glass-tint-accent` |
| `--color-on-accent` | `#FFFFFF` | `#05271A` |
| `--color-text-primary` | `--label-1` | `--label-1` |
| `--color-text-secondary` | `--label-2-web` | `--label-2-web` |
| `--color-text-tertiary` | `--label-3` | `--label-3` |
| `--color-text-quaternary` | `--label-4` | `--label-4` |
| `--color-text-link` | `--green-700` | `--green-400` |
| `--color-status-success` | `--sys-green` | `--sys-green` |
| `--color-status-warning` | `--sys-orange` | `--sys-orange` |
| `--color-status-error` | `--sys-red` | `--sys-red` |
| `--color-status-info` | `--sys-blue` | `--sys-blue` |
| `--color-status-*-tint` | 14% alpha of the status color | 18% alpha |
| `--color-surface-base` | `--bg-base` | `--bg-base` |
| `--color-surface-grouped` | `--bg-grouped` | `--bg-grouped` |
| `--color-surface-card` | `--bg-grouped-elevated` | `--bg-grouped-elevated` |
| `--color-surface-glass` | `--glass-regular` | `--glass-regular` |
| `--color-surface-glass-thin` | `--glass-thin` | `--glass-thin` |
| `--color-surface-glass-thick` | `--glass-thick` | `--glass-thick` |
| `--color-separator` | `--separator` | `--separator` |
| `--color-fill` / `-secondary` / `-tertiary` | `--fill-1` / `-2` / `-3` | same |
| `--color-glass-border` | `--glass-border` | `--glass-border` |
| `--color-scrim` | `rgba(0,0,0,0.25)` | `rgba(0,0,0,0.5)` |

Status → meaning in CrocApp: **success** = transfer complete, E2E trust badge. **warning** = overwrite conflict, auto-accept enabled. **error** = failed / declined / blocked-unsafe. **info** = local-network-denied, relay notes, "how it works".

## Theming on web

Every token is a `light-dark()` pair resolved by `color-scheme`. `:root` declares `light dark`, so an untouched page follows the OS; `[data-theme="dark"]` / `[data-theme="light"]` pin `color-scheme` and win in both directions. `tokens.css` ships this — a consuming page sets `data-theme` from a small inline script before first paint (avoids a flash) and needs nothing else.

## Contrast (verified, WCAG 2.2)

Recomputed from the hex values above on 2026-07-26. **Light is the constrained theme — check it first.**

| Pair | Ratio | Verdict |
|---|---|---|
| `--color-accent` on base / grouped / its own tint | 3.41 / 3.06 / 2.98 | UI + large text only; never a letter |
| `--color-accent-text` `#178055` on base | 4.94 | AA body |
| `--color-accent-text` on grouped / accent tint | 4.42 / 4.31 | fails body — use the step below |
| `--color-accent-text-on-tint` `#116243` on base / grouped / accent tint | 7.36 / 6.60 / 6.43 | AA body everywhere |
| `--label-2` 0.60 on base | 3.44 | fails body — Apple's own secondaryLabel |
| `--label-2-web` 0.75 on base / grouped | 5.15 / 4.82 | AA body |
| `--label-3` on base | 1.74 | decorative fill only |
| `--color-accent` band of `--shadow-focus-ring` on base / on the accent fill | 3.41 / 3.41 | AA non-text, rule 7 |
| `#FFFFFF` on `--color-accent` | 3.41 | filled-button deviation, rule 3 |
| `#FFFFFF` on `--color-status-error` | 3.55 | filled-button deviation, rule 3 |
| `--color-status-success` / `-warning` / `-error` on its own tint | 1.98 / 1.96 / 2.95 | nothing |
| `--color-status-success` / `-warning` / `-error` / `-info` on base | 2.22 / 2.20 / 3.55 / 4.02 | fill and glyph only |

Dark, for the record: accent 9.44 on base, 7.65 on card, 7.69 on its own tint; `--color-on-accent` 7.19 on the accent; `--label-2` 6.36 on base; every status color ≥ 4.91 on its own tint. Nothing in dark needs a substitute, which is why all three accent-text aliases collapse to `--green-400` there.

### Rules

1. **Accent as text is not accent as a fill.** Icons, fills, borders and progress bars keep `--color-accent` — they owe 3:1 and clear it. Anything with a letter in it takes `--color-accent-text` on `--color-surface-base` / `--color-surface-card`, and `--color-accent-text-on-tint` on every other light surface: `--color-accent-tint`, and `--color-surface-grouped`, which is the landing page's default fill. `--green-800` is the only accent step that clears AA everywhere in light.

2. **A status color is a fill, never a foreground.** In light it fails on its own tint (1.96 – 2.95) and three of four fail on base. Status *text* — banner titles, tinted-destructive labels, trust-badge labels — is `--color-text-primary`; the tint and border carry the semantic. Status *glyphs* may stay in the kind color: they are `aria-hidden` and always redundant with an adjacent label (`iconography.md`), which makes them decorative, so 1.4.11 does not bind them. They do read faint in light — that is why the label, not the glyph, has to carry the meaning. Never "improve" a banner by tinting its body copy.

3. **Filled prominent and destructive buttons ship at 3.41:1 and 3.55:1.** Both clear 3:1, neither clears 4.5:1. Accepted, because it is what Apple's own filled controls measure, on two conditions: the label stays ≥ 17px semibold and never shrinks, and small sizes use a tinted variant instead of a filled one.

4. **`--color-text-secondary` is not `--label-2` in light.** Apple's secondaryLabel (0.60) is 3.44:1 on white, below AA for anything under large text — which is most of a web page. `--label-2` keeps the true system value so the app stays visually native; the alias resolves to `--label-2-web` (0.75). An app view consuming these tokens directly wants `--label-2`.

5. **`--color-text-tertiary` is not a text color and not a UI-boundary color.** 1.74:1. Decorative fills only. Anything a sighted user has to *see* — disclosure chevrons, remove controls, empty-state glyphs — takes secondary or better.

6. **`--color-text-link` is `--green-700`, not the accent**, and follows rule 1: on `--color-surface-grouped` a link needs `--green-800`, or it needs to sit on a card.

7. **The focus ring owes 3:1 and is not decoration.** It is two 2px bands — `--color-surface-base` inside, `--color-accent` outside — precisely so one of them always has a 3.41:1 edge against whatever it surrounds, including the accent-filled button. A tint cannot do this job: `--glass-tint-accent` at 12% composites to 1.14:1 on base, which is how the ring shipped invisible before 2026-07-27. Non-text contrast (1.4.11) binds focus indicators; a calm-looking ring that nobody can see is a failure, not a style.
