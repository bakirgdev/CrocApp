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
| `--sys-yellow` | `#FFCC00` | `#FFD60A` |

## Labels, fills, separators

| Token | Light | Dark |
|---|---|---|
| `--label-1` | `rgba(0,0,0,1)` | `rgba(255,255,255,1)` |
| `--label-2` | `rgba(60,60,67,0.60)` | `rgba(235,235,245,0.60)` |
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
| `--color-accent-tint` | `--glass-tint-accent` | `--glass-tint-accent` |
| `--color-on-accent` | `#FFFFFF` | `#05271A` |
| `--color-text-primary` | `--label-1` | `--label-1` |
| `--color-text-secondary` | `--label-2` | `--label-2` |
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

Dark is opt-in via `data-theme="dark"` on `<html>`, so every value stays a single registered light/dark pair. To follow the OS, mirror it once in the consuming page:

```css
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { color-scheme: dark; }
}
```

…and either duplicate the `[data-theme="dark"]` block under that query, or set `data-theme` from a small inline script before first paint (avoids a flash). The theme toggle must win in both directions.

## Contrast (verified, WCAG 2.2)

Computed 2026-07-25 from the hex values above.

| Pair | Ratio | Verdict |
|---|---|---|
| `#1E9E6A` on `#FFFFFF` | 3.41 | ✅ large text / UI ❌ body text |
| `#1E9E6A` on `#F2F2F7` | 3.06 | ✅ large text / UI ❌ body text |
| `#FFFFFF` on `#1E9E6A` | 3.41 | ❌ AA for a 17px semibold button label |
| `#178055` on `#FFFFFF` | 4.94 | ✅ AA body text |
| `#178055` on `#F2F2F7` | 4.42 | ❌ AA body text — see below |
| `#116243` on `#F2F2F7` | 6.60 | ✅ AA body text |
| `#2DC585` on `#000000` | 9.44 | ✅ AAA |
| `#2DC585` on `#1C1C1E` | 7.65 | ✅ AAA |
| `#05271A` on `#2DC585` | 7.19 | ✅ AAA |
| `#FF3B30` on `#FFFFFF` | 3.55 | ✅ large only |
| `#FF9500` on `#FFFFFF` | 2.20 | ❌ text — icon/fill only |
| `#34C759` on `#FFFFFF` | 2.22 | ❌ text — icon/fill only |
| `#007AFF` on `#FFFFFF` | 4.02 | borderline; large text only |
| `#FF453A` on `#000000` | 6.16 | ✅ |
| `#FF9F0A` on `#000000` | 10.22 | ✅ |
| `#30D158` on `#000000` | 10.39 | ✅ |
| `#0A84FF` on `#000000` | 5.76 | ✅ |

Consequences to respect:

- Light-theme prominent buttons carry white on `--color-accent` at 3.41:1. Keep the label ≥ 17px semibold (large-text threshold at bold weight) and never shrink it; for a small prominent button use `--green-700` as the fill.
- Status **titles** inside a `StatusBanner` are drawn in the status color on its own tint — legible for orange/green only because tint backgrounds are near-white/near-black. Body copy in a banner uses `--color-text-secondary`, not the status color. Do not "improve" it by tinting the body text.
- `--color-text-link` is `--green-700`, not the accent: `--green-600` is 3.41:1 on white and fails body text. Even `--green-700` only clears AA on `--color-surface-base` (4.94); on the grouped background it is 4.42 and fails. **Small accent text and links on `--color-surface-grouped` need `--green-800`** — or put the link on a card. This bites the landing page, whose default page fill is grouped.
- Dark theme has margin everywhere; light theme is the constrained one. Check light first.
