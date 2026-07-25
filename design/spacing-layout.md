# Spacing, radius, layout

4pt grid throughout. Every gap, pad and inset resolves to one of these steps.

## Spacing scale

| Token | Value |
|---|---|
| `--space-0` | 0 |
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

## Borders

| Token | Value |
|---|---|
| `--border-hairline` | 1px |
| `--border-focus` | 2px |

Grouped lists separate rows with `inset 0 -0.5px 0 var(--color-separator)` (a half-pixel inset shadow, not a border) so the row corners stay clean; the last row omits it.
