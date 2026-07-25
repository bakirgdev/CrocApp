# Components

Fourteen primitives cover every screen. Measurements below are exact — they come from the design system's component source, not from eyeballing a render. Anything not listed as a token is a component constant; keep it in the component, not scattered at call sites.

Composition order on a screen: page (`--color-surface-grouped`) → `GlassCard` → grouped rows / controls → buttons.

Every foreground here obeys the six rules in `colors.md` → Contrast. Two of them decide most of this file: **accent never labels anything** (use `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and on tint), and **a status color is a fill, never a foreground** (status *text* is `--color-text-primary`; the tint carries the meaning).

---

## Button

Capsule, Apple prominent style. Icon before and/or after the label.

**Sizes**

| Size | Height | Padding | Font | Gap | Icon |
|---|---|---|---|---|---|
| large | `--control-height-lg` 50 | `0 22px` | `--type-headline` 17 | 8 | 20 |
| medium | `--control-height-md` 38 | `0 16px` | `--type-callout` 16 | 6 | 18 |
| small | `--control-height-sm` 30 | `0 12px` | `--type-footnote` 13 | 5 | 15 |

Always `--weight-semibold`, `--tracking-headline`, `line-height: 1`, `--radius-capsule`, `white-space: nowrap`.

**Variants**

| Variant | Background | Foreground | Border | Pressed |
|---|---|---|---|---|
| `prominent` | `--color-accent` | `--color-on-accent` | transparent | `--color-accent-pressed` |
| `secondary` | `--color-accent-tint` | `--color-accent-text-on-tint` | transparent | tint mixed 12% toward accent |
| `destructive` | `--color-status-error` | `#fff` | transparent | error mixed 82% toward black |
| `destructive-tinted` | `--color-status-error-tint` | `--color-text-primary` | 22% error | tint mixed 12% toward error |
| `glass` | `--color-surface-glass` + regular blur | `--color-accent-text` | `--color-glass-border` | `--color-surface-glass-thick` |
| `plain` | transparent | `--color-accent-text` | transparent | `--color-fill-tertiary` |

`prominent`, `destructive` and `glass` carry `--shadow-sm`.

Foreground caveats, all from `colors.md`:

- `plain` and `glass` sit on whatever is behind them. `--color-accent-text` only clears AA on `--color-surface-base` / `--color-surface-card`; on `--color-surface-grouped` the label must be `--color-accent-text-on-tint`.
- `prominent` (3.41:1) and `destructive` (3.55:1) are the documented filled-button deviation. Label stays ≥ 17px semibold. **There is no `sm` filled button** — a small accent or destructive action uses `secondary` or `destructive-tinted`.
- `destructive-tinted` cannot draw its label in the error color (2.95:1). The tint plus the 22% border carries "destructive"; the leading glyph may stay `--color-status-error`.

**States** — pressed: `scale(var(--press-scale))` + pressed background, `--dur-fast` `--ease-out`. Focused: `--shadow-focus-ring` replaces the variant shadow. Disabled: `opacity: 0.4`, no pointer.

Screen usage: one `prominent` primary action per screen; `destructive` only for Decline / Cancel transfer / Clear history; `glass` for floating actions over content.

The incoming accept gate needs a designed exit that is not Decline — declining tells the sender something, backing out should not. Not yet specced.

---

## GlassCard

The default content container. Props: `material` (thin | regular | thick | solid), `tinted`, `radius` (defaults `lg`), `padding` (defaults `--space-6`), `elevated`.

Border `1px --color-glass-border`, shadow `--shadow-glass` when elevated. `tinted` swaps the fill for `--color-accent-tint` — use it for the one card you want to read as "active/selected", not as decoration.

---

## DropZone

The empty send target: iPhone/iPad staging area, and the macOS full-window "Drop to send" overlay.

Idle: `--radius-lg`, `2px` dashed `--color-separator`, fill `--color-fill-tertiary`, min height 168, centered column at gap `--space-4`. `upload` glyph at 44 stroke 1.5 in `--color-text-secondary`, title `--type-headline` primary, hint `--type-subhead` secondary.

Drag-over: border becomes `2px` solid `--color-accent`, fill `--color-accent-tint`, glyph and title `--color-accent-text-on-tint`. Transition `--dur-fast` `--ease-out`; no scale, no bounce.

macOS overlay: same states at full-window size over `--color-scrim`, `--radius-2xl`, `--color-surface-glass-thick` + `--blur-thick`. This is the one place `--radius-2xl` is used.

**A drop target is not an input.** Every DropZone ships beside a real file-picker button — drag-and-drop is unavailable to keyboard and most assistive tech, so it can never be the only way to add files.

---

## SegmentedControl

iOS picker (e.g. Files | Text). Track: `--color-fill-tertiary`, `--radius-sm`, 2px inset padding, equal-width grid. Thumb: `--color-surface-base`, radius `calc(var(--radius-sm) - 2px)`, `--shadow-sm`, slides on `left` over `--dur-base` `--ease-out`.

Segments: `--type-subhead` 15px, semibold when selected / medium otherwise, `--color-text-primary` vs `--color-text-secondary`, min height `--control-height-sm`, padding `6px --space-4`. A hairline `inset 1px 0 0 --color-separator` divides adjacent *unselected* segments only.

---

## CodeField

Monospaced entry for `NNNN-word-word-word`, with a paste affordance.

Wrapper: height `--control-height-lg` 50, padding `0 6px 0 14px`, `--color-surface-base`, `--radius-md`, 1px border. Border color: `--color-separator` idle → `--color-accent` focused → `--color-status-error` invalid. Focused (and valid) adds `--shadow-focus-ring`. Disabled `opacity: 0.5`.

Input: `--font-mono`, `--type-code-body` 15, `--tracking-code`, autocapitalize/autocorrect/spellcheck off.

Paste button: height 38, padding `0 12px`, `--radius-sm`, `--color-accent-text-on-tint` on `--color-accent-tint`, `--type-footnote` semibold, `clipboard` glyph at 15.

---

## SettingsRow + Switch

Inset-grouped list row. Types: `toggle`, `field` (right-aligned inline text field), `disclosure` (chevron), `value` (static trailing detail).

Row: min height 52, padding `10px --space-5`, gap `--space-4`, `--color-surface-card`. `first`/`last` flags round the outer corners at `--radius-md`; every row but the last draws `inset 0 -0.5px 0 --color-separator`. Disabled `opacity: 0.5`.

Leading icon tile: 29×29, radius 7, fill `iconTint` or `--color-accent`, white glyph at 17 / stroke 2.

Title `--type-body` with `--tracking-body`, truncating. Subtitle `--type-footnote` `--color-text-secondary`. Trailing value `--type-body` secondary. Chevron `chevron-right` at 18, stroke 2.4, `--color-text-secondary` — it is the only signal that a row navigates, so it does not get tertiary (1.74:1).

Switch: 51×31 capsule, 2px padding, 27px `--paper` knob with `--shadow-knob`. Track `--color-status-success` on, `--color-fill` off, `--dur-base`.

---

## FileRow

Send queue / incoming preview row. Min height 48, padding `8px --space-4`, gap `--space-3`, `--color-surface-card` when `grouped`, same first/last rounding + separator rules as SettingsRow.

Type icon at 20 in `--color-accent`, mapped: `folder → folder`, `image → image`, `text → file-text`, `doc → file`.

Filename is **middle-truncated**: the last 8 characters (extension + tail) are pinned in a non-shrinking span so the extension always stays visible; the head ellipsises. Size label `--type-footnote` secondary, tabular figures. Remove control: `circle-x` at 20, `--color-text-secondary`, `aria-label="Remove <name>"` — it is an interactive affordance, so tertiary is not available to it.

---

## CodePhraseDisplay + QRFrame

The sender's "ready to send" state. Centered column, gap `--space-5`:

1. Eyebrow "READY TO SEND" — `--type-footnote`, semibold, `--tracking-eyebrow`, uppercase, secondary.
2. The code — `--font-mono`, `--type-code-hero` 30/38, bold, `--tracking-code`, `user-select: all`, wraps on word break.
3. Copy button — capsule, `--color-accent-text-on-tint` on `--color-accent-tint`, `--type-subhead` semibold, padding `--space-3 --space-5`; glyph flips `copy → check` and label `Copy Code → Copied` when copied.
4. QR frame — default 168×168, white background (always white, both themes — scanners need it), `--radius-md`, 12px padding, `--shadow-md`, 1px `--color-separator` border. Payload is `croc://<code>`.
5. Optional caption — `--type-callout` secondary, max-width 320.

---

## TransferProgress + ProgressBar

`ProgressBar`: height 6, `--radius-capsule`, track `--color-fill-tertiary`, fill `--color-accent`. Determinate animates width `--dur-base` `--ease-out`. Indeterminate: 40%-wide fill sliding `-40% → 100%` over 1.2s, infinite.

`TransferProgress` is the dual-bar block:

- **Direction header** — `arrow-up`/`arrow-down` at 18 stroke 2.4 in `--color-accent`, plus the literal word **Sending** or **Receiving** in `--type-headline` semibold. This is the fix for the old UI bleeding Send status onto the Receive screen: the word and the arrow both change, and neither is optional.
- Current file: middle-truncated name (`--type-callout`), bar, caption row `File N of M` ← → `done / size`.
- Overall: bar, caption row `Total done / size` ← → live speed in `--weight-medium` primary.

Captions are `--type-caption1` 12px, secondary, tabular figures.

---

## StatusBanner

Inline advisory. Padding `--space-4 --space-5`, gap `--space-3`, `--radius-md`, background = kind tint, border `1px color-mix(kind color 22%, transparent)`.

| Kind | Color | Glyph | `role` |
|---|---|---|---|
| info | `--color-status-info` | `info` | status |
| warning | `--color-status-warning` | `triangle-alert` | status |
| error | `--color-status-error` | `circle-alert` | **alert** |
| success | `--color-status-success` | `circle-check` | status |

Leading glyph 19 stroke 2 in the kind color — decorative, per `colors.md` rule 2. Title `--type-subhead` semibold in **`--color-text-primary`**; body `--type-footnote` in `--color-text-secondary`. Optional trailing action slot.

The title is not drawn in the kind color: on its own tint that measures 1.96 – 2.95:1 in light. The tint and the border are what say "warning", and the title says it in words.

---

## StatusBlock

Large centered result (transfer done / failed). 64px circle filled with the kind tint holding a 34px stroke-2 glyph in the kind color, then title `--type-title3` semibold primary, then detail `--type-callout` secondary. Padding `--space-6`, gap `--space-3`.

The glyph is decorative (`colors.md` rule 2) — the title below it states the outcome in words, and never in color alone.

---

## TrustBadge

End-to-end-encryption reassurance.

- `pill` (default): inline capsule, background `--color-status-success-tint`, label `--color-text-primary`, padding block `--pill-pad-block` / inline `--pill-pad-inline-start` `--pill-pad-inline-end`, `--type-footnote` semibold, `lock` glyph at `--pill-icon-size` stroke 2.2 in `--color-status-success`. Sits in the Home header and on transfer screens.
- `full`: row card, `--radius-md`, success tint background, 22% success border, 34px solid-success circle with a `--paper` `shield-check` at 19, label `--type-subhead` semibold + optional `--type-footnote` detail. Used on the "How it works" trust screen.

The pill's label is primary, not success: success on its own tint is 1.98:1 in light. The `full` variant escapes this by inverting — a solid success fill with the glyph knocked out of it.

Claim only what is true: croc is PAKE-authenticated and end-to-end encrypted, and the relay sees ciphertext only. Do not extend the copy beyond that.

---

## EmptyState

Mirrors `ContentUnavailableView`. Centered column, gap `--space-3`, padding `--space-9 --space-6` (`--space-6` when `compact`). Icon 44 (34 compact), stroke 1.5, `--color-text-secondary`. Title `--type-headline` semibold primary. Description `--type-subhead`, max-width 300, secondary. Optional action slot with `--space-3` top margin.

---

## SheetHeader

iOS sheet toolbar: `1fr auto 1fr` grid — leading Cancel, centered title, trailing confirm. Min height 52, padding `--space-4 --space-5`, `--color-surface-glass-thick` + regular blur, bottom hairline `--color-separator`, top corners `--radius-xl`.

Title `--type-headline` semibold. Actions `--type-body` in `--color-accent-text`; confirm is semibold when prominent, `--color-text-primary` when destructive (the sheet's own copy names the consequence — a red word at 3.55:1 does not), `--color-text-tertiary` when disabled. Disabled is the one place tertiary is right: it is meant to read as unavailable.

---

## Icon

24×24 viewBox, `fill: none`, `stroke: currentColor`, round caps and joins, default size 22, default stroke width 1.8. Heavier strokes (2 – 2.4) for small glyphs so they hold weight. Always `aria-hidden` — the label next to it carries the meaning. See `iconography.md`.
