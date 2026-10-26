# Colors

Apple system color model (iOS 26, macOS 26) plus a croc-green brand scale. The base palette holds literal values; **semantic aliases are what you consume**. Every themed token is one `light-dark()` pair (`web.md` → Theming); the app reads the same pairs from the asset catalog (`swiftui.md` → Colors).

## Brand: croc green

Theme-independent literals. The accent alias swaps which step it points at. The scale starts at 200 because nothing in the system needs a lighter opaque green: washes are `--color-accent-tint`, which is translucent.

| Token | Hex | Use |
|---|---|---|
| `--green-200` | `#97DBBD` | |
| `--green-300` | `#57C598` | |
| `--green-400` | `#2DC585` | **dark-mode accent** |
| `--green-500` | `#22B074` | dark-mode pressed |
| `--green-600` | `#1E9E6A` | **light-mode accent (brand color)** |
| `--green-700` | `#178055` | light-mode filled-button background; small accent text |
| `--green-800` | `#116243` | light-mode pressed; accent text on tints |
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
| `--paper` | `#FFFFFF` | `#000000` |
| `--label-1` | `rgba(0,0,0,1)` | `rgba(255,255,255,1)` |
| `--label-2` | `rgba(60,60,67,0.60)` | `rgba(235,235,245,0.60)` |
| `--label-2-text` | `rgba(60,60,67,0.78)` | `rgba(235,235,245,0.60)` |
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

The app's page fill is `--bg-grouped` with cards on `--bg-grouped-elevated`. The web's page fill is `--bg-base` (`web.md` → Page fill).

## Glass fills

Pair each with the matching `--blur-*` and `--glass-saturate` (see `materials.md`).

| Token | Light | Dark |
|---|---|---|
| `--glass-thin` | `rgba(255,255,255,0.55)` | `rgba(30,30,32,0.55)` |
| `--glass-regular` | `rgba(255,255,255,0.72)` | `rgba(28,28,30,0.68)` |
| `--glass-thick` | `rgba(255,255,255,0.86)` | `rgba(28,28,30,0.86)` |
| `--glass-tint-accent` | `rgba(30,158,106,0.12)` | `rgba(45,197,133,0.16)` |
| `--glass-border` | `rgba(255,255,255,0.60)` | `rgba(255,255,255,0.14)` |
| `--glass-highlight` | `rgba(255,255,255,0.75)` | `rgba(255,255,255,0.10)` |

## Semantic aliases: consume these

| Alias | Light | Dark |
|---|---|---|
| `--color-accent` | `--green-600` | `--green-400` |
| `--color-accent-solid` | `--green-700` | `--green-400` |
| `--color-accent-pressed` | `--green-800` | `--green-500` |
| `--color-accent-text` | `--green-700` | `--green-400` |
| `--color-accent-text-on-tint` | `--green-800` | `--green-400` |
| `--color-accent-tint` | `--glass-tint-accent` | `--glass-tint-accent` |
| `--color-on-accent` | `#FFFFFF` | `#05271A` |
| `--color-on-status` | `#FFFFFF` | `#FFFFFF` |
| `--color-text-primary` | `--label-1` | `--label-1` |
| `--color-text-secondary` | `--label-2-text` | `--label-2-text` |
| `--color-text-tertiary` | `--label-3` | `--label-3` |
| `--color-text-quaternary` | `--label-4` | `--label-4` |
| `--color-text-link` | `--color-accent-text` | `--color-accent-text` |
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

## Contrast (verified, WCAG 2.2)

Every row is recomputed from `tokens.css` by `scripts/verify-design.sh` (contrast phase), which also asserts the rules below as invariants, the alias rules (4 and 6, the dark accent collapse) and the two bands of `--shadow-focus-ring` (7). Run it after touching any color. **Light is the constrained theme: check it first.**

| Pair | Ratio | Verdict |
|---|---|---|
| `--color-accent` on base / grouped / its own tint | 3.41 / 3.06 / 2.99 | UI + large text only; never a letter |
| `--color-accent-text` `#178055` on base / card | 4.94 / 4.94 | AA body |
| `--color-accent-text` on grouped / accent tint | 4.42 / 4.32 | fails body: use the step below |
| `--color-accent-text` on a `--color-fill-tertiary` wash (inline code, striped table row) | 4.28 | fails body: use the step below |
| `--color-accent-text-on-tint` `#116243` on base / grouped / accent tint / fill wash | 7.36 / 6.60 / 6.45 / 6.38 | AA body everywhere |
| `--label-2` 0.60 on base / grouped | 3.44 / 3.30 | glyphs (3:1) and large text only: Apple's own secondaryLabel |
| `--label-2-text` 0.78 on base / grouped | 5.63 / 5.26 | AA body |
| `--color-text-secondary` (`--label-2-text`) on accent tint / fill-tertiary wash over grouped / error tint over grouped | 5.19 / 4.83 / 4.70 | AA body. The error tint over grouped is the weakest of the four status tints |
| `--label-3` on base | 1.73 | decorative fill only |
| `--color-accent` band of `--shadow-focus-ring` on base, and the base band on `--color-accent-solid` | 3.41 / 4.94 | AA non-text, rule 7 |
| `--glass-tint-accent` composited on base | 1.14 | not a focus indicator, rule 7 |
| `--color-on-accent` on `--color-accent-solid` `#178055` / `--color-accent-pressed` `#116243` | 4.94 / 7.36 | AA body, rule 3 |
| `--color-on-status` on `--color-status-error` | 3.55 | filled-destructive deviation, rule 3 |
| `--color-status-success` / `-warning` / `-error` on its own tint | 1.98 / 1.96 / 2.94 | nothing |
| `--color-status-success` / `-warning` / `-error` / `-info` on base | 2.22 / 2.20 / 3.55 / 4.02 | fill and glyph only |

Dark, for the record: accent 9.44 on base, 7.65 on card, 7.72 on its own tint; `--color-on-accent` 7.19 on `--color-accent-solid` (the accent itself) and 5.74 on `--color-accent-pressed`; `--color-on-status` 3.41 on `--color-status-error`, the same rule-3 deviation as light; `--label-2` 6.36 on base; `--color-text-secondary` (the same 0.60 in dark) 5.95 on a card and 4.74 on a success tint over a card, its weakest surface; every status color on its own tint: success 8.05, warning 7.93, error 5.25, info 4.92 (all AA body). Nothing else in dark needs a substitute, which is why `--color-accent-solid` and all three accent-text aliases collapse to `--green-400` there.

### Rules

1. **Accent as text is not accent as a fill.** Icons, fills, borders and progress bars keep `--color-accent`: they owe 3:1 and clear it. Anything with a letter in it takes `--color-accent-text` on `--color-surface-base` / `--color-surface-card`, and `--color-accent-text-on-tint` on every other light surface: `--color-accent-tint`, a `--color-fill-tertiary` wash (inline code, striped table rows: 4.28:1 for the plain step), and `--color-surface-grouped`, which is the app's page fill. In the app that means a `.bordered` or plain button's label too, never the inherited tint (`swiftui.md` → Colors). `--green-800` is the only accent step that clears AA everywhere in light.

2. **A status color is a fill, never a foreground.** In light it fails on its own tint (1.96 - 2.94) and three of four fail on base. Status *text* (banner titles, tinted-destructive labels, trust-badge labels, the app's destructive button labels) is `--color-text-primary`; the tint and border carry the semantic. Status *glyphs* may stay in the kind color: they are `aria-hidden` and always redundant with an adjacent label (`iconography.md`), which makes them decorative, so 1.4.11 does not bind them. They do read faint in light, which is why the label, not the glyph, has to carry the meaning. Never "improve" a banner by tinting its body copy.

3. **A filled prominent button is `--color-accent-solid`, not `--color-accent`.** White on the brand green is 3.41:1, so light fills with `--green-700` (4.94:1, AA body) and presses to `--green-800` (7.36:1); dark keeps the accent, which already clears 7.19:1. Accent as a background that carries a label is the one use `--color-accent` does not serve. The filled destructive button has no such step and ships at 3.55:1 light, 3.41:1 dark: the system has one error red (`--sys-red`, Apple's own value, and the app's destructive controls read as the system's), darkening it for one control would fork the status color from every glyph, tint and border that share it, and a darker red is a new base color rather than an existing ramp step. It clears 3:1 on three conditions: the label stays ≥ 17px semibold and never shrinks, small sizes use `destructive-tinted`, and filled destructive stays limited to Decline and confirming Clear History (`components.md` → Button). Their ink is `--color-on-accent` and `--color-on-status`: the only two places a knocked-out label is allowed, and neither is a raw literal.

4. **Secondary text is `--color-text-secondary`, never Apple's `.secondary`.** The system's secondaryLabel (`--label-2`, 0.60) is 3.44:1 on white and 3.30:1 on the grouped page: enough for a glyph (3:1), not for text. `--color-text-secondary` resolves to `--label-2-text` (0.78 in light, the system's own 0.60 in dark), which clears 4.5:1 on every surface that carries it: base, card, grouped, the accent tint, a fill wash and each of the four status tints. At 0.75 the error tint over grouped measured 4.36 and the DropZone fill 4.48, which is why 0.78. The app mirrors the alias as the `ColorTextSecondary` color set, so the web and the app read one value. `.secondary` and `.tertiary` are for non-text (a glyph) and large text only. Large text is 24px or more, or 18.66px or more at weight 700 (WCAG's 18pt, and 14pt bold): in this scale `--type-large-title`, `--type-title1`, `--type-title2` and `--type-code-hero`. Body, callout, subhead, footnote and caption text, and `--type-title3` at 600, are not large. A string we write inside a system control (a Form footer, an EmptyState description) takes the token explicitly; only text the system draws itself (a placeholder, a picker's value) keeps Apple's own.

5. **`--color-text-tertiary` is not a text color and not a UI-boundary color.** 1.73:1. Decorative fills only. Anything a sighted user has to *see* (disclosure chevrons, remove controls, empty-state glyphs) takes secondary or better.

6. **`--color-text-link` is `--color-accent-text`, not the accent**, and follows rule 1: a link on `--color-surface-grouped` or a tint takes `--color-accent-text-on-tint`, or sits on a card.

7. **The focus ring owes 3:1 and is not decoration.** It is two 2px bands, `--color-surface-base` inside and `--color-accent` outside, precisely so one of them always has a 3.41:1 edge against whatever it surrounds, including the filled button, whose `--color-accent-solid` fill reads against the base band at 4.94:1. A tint cannot do this job: `--glass-tint-accent` at 12% composites to 1.14:1 on base, which leaves the ring invisible. Non-text contrast (1.4.11) binds focus indicators; a calm-looking ring that nobody can see is a failure, not a style.
