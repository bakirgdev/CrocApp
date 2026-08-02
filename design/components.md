# Components

These primitives cover every screen. Measurements are exact — they come from the design system's component source, not from eyeballing a render. Anything not listed as a token is a component constant; keep it in the component, not scattered at call sites.

Composition order on a screen: page (`--color-surface-grouped`) → `GlassCard` → grouped rows / controls → buttons.

Every foreground here obeys the seven rules in `colors.md` → Contrast. Two of them decide most of this file: **accent never labels anything** (use `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and on tint), and **a status color is a fill, never a foreground** (status *text* is `--color-text-primary`; the tint carries the meaning).

---

## States

Every interactive element supports the same six states. A component that needs a seventh needs a reason written down.

| State | What changes | Timing |
|---|---|---|
| rest | the variant's own values | — |
| hover | the variant's **pressed background**, nothing else. No scale, no lift, no shadow change | `--dur-fast` `--ease-standard` |
| pressed | hover, plus `scale(var(--press-scale))` | `--dur-fast` `--ease-out` |
| focus | `--shadow-focus-ring`, replacing the variant's own shadow | none |
| disabled | `--opacity-disabled` on controls, `--opacity-disabled-container` on rows and fields, no pointer | none |
| loading | see below | — |

**Hover is pointer-only** and never exists on touch. Nothing may be discoverable only on hover: no hover-only buttons, no hover-to-reveal remove controls. See `platforms.md` → Hover.

**Two disabled opacities, on purpose.** A control dims to 0.4 because it is one object. A row or a field dims to 0.5 because it is a composite whose subtitle and separator would otherwise disappear before its title does.

**Loading.** No skeletons anywhere in this system. Work with a known extent shows `ProgressBar`; work without one shows the indeterminate bar. A button that is working keeps its label and its width, swaps its leading glyph for a spinner, and goes disabled. It never collapses to a bare spinner and never changes size, because a control that resizes under the pointer is a control you cannot click twice.

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
| `secondary` | `--color-accent-tint` | `--color-accent-text-on-tint` | transparent | `color-mix(in srgb, var(--color-accent) 12%, var(--color-accent-tint))` |
| `destructive` | `--color-status-error` | `--color-on-status` | transparent | `color-mix(in srgb, var(--color-status-error) 82%, black)` |
| `destructive-tinted` | `--color-status-error-tint` | `--color-text-primary` | 22% error | `color-mix(in srgb, var(--color-status-error) 12%, var(--color-status-error-tint))` |
| `glass` | `--color-surface-glass` + regular blur | `--color-accent-text` | `--color-glass-border` | `--color-surface-glass-thick` |
| `plain` | transparent | `--color-accent-text` | transparent | `--color-fill-tertiary` |

`prominent`, `destructive` and `glass` carry `--shadow-sm`.

Foreground caveats, all from `colors.md`:

- `plain` and `glass` sit on whatever is behind them. `--color-accent-text` only clears AA on `--color-surface-base` / `--color-surface-card`; on `--color-surface-grouped` the label must be `--color-accent-text-on-tint`.
- `prominent` (3.41:1) and `destructive` (3.55:1) are the documented filled-button deviation. Label stays ≥ 17px semibold. **There is no `sm` filled button** — a small accent or destructive action uses `secondary` or `destructive-tinted`.
- `destructive-tinted` cannot draw its label in the error color (2.94:1). The tint plus the 22% border carries "destructive"; the leading glyph may stay `--color-status-error`.

States are the shared six above; the Pressed column feeds both hover and pressed.

Screen usage: one `prominent` primary action per screen; `destructive` only for Decline / Cancel transfer / Clear history; `glass` for floating actions over content.

The accept gate's two actions and its third, unlabelled exit are specced below.

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

Wrapper: height `--control-height-lg` 50, padding `0 6px 0 14px`, `--color-surface-base`, `--radius-md`, 1px border. Border color: `--color-separator` idle → `--color-accent` focused → `--color-status-error` invalid. Focused (and valid) adds `--shadow-focus-ring`. Disabled `--opacity-disabled-container`.

Input: `--font-mono`, `--type-code-body` 15, `--tracking-code`, autocapitalize/autocorrect/spellcheck off.

Paste button: height 38, padding `0 12px`, `--radius-sm`, `--color-accent-text-on-tint` on `--color-accent-tint`, `--type-footnote` semibold, `clipboard` glyph at 15.

---

## SettingsRow + Switch

Inset-grouped list row. Types: `toggle`, `field` (right-aligned inline text field), `disclosure` (chevron), `value` (static trailing detail).

Row: min height 52, padding `10px --space-5`, gap `--space-4`, `--color-surface-card`. `first`/`last` flags round the outer corners at `--radius-md`; every row but the last draws `inset 0 -0.5px 0 --color-separator`. Disabled `--opacity-disabled-container`.

Leading icon tile: 29×29, radius 7, fill `iconTint` or `--color-accent`, `--color-on-accent` glyph at 17 / stroke 2.

Title `--type-body` with `--tracking-body`, truncating. Subtitle `--type-footnote` `--color-text-secondary`. Trailing value `--type-body` secondary. Chevron `chevron-right` at 18, stroke 2.4, `--color-text-secondary` — it is the only signal that a row navigates, so it does not get tertiary (1.73:1).

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

The title is not drawn in the kind color: on its own tint that measures 1.96 - 2.94:1 in light. The tint and the border are what say "warning", and the title says it in words.

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

## AcceptGate

The incoming request. Not a sheet and not an alert: it is a phase of the transfer screen, so it cannot be dismissed by accident.

Composition: direction header, `TrustBadge` pill, the file list as `FileRow`s, a `StatusBanner` for each of overwrite conflicts and blocked-unsafe items, then the two actions. Decline is `destructive`, Accept is `prominent`. Nothing here auto-advances and nothing is preselected.

**Two answers and one silence.** Declining and leaving are different acts and the design must not blur them:

| Exit | What the other device learns | What we do |
|---|---|---|
| Decline | that you said no, immediately | respond, then terminal phase |
| Accept | that you said yes | respond, then transfer |
| Navigating away | nothing | respond with nothing. The request stays live |

Leaving the screen is the third exit and it is deliberately unlabelled, because a "Not now" button would promise a deferral the protocol cannot deliver. The sender is blocked on an answer; silence is simply the answer not arriving yet, which is also what happens if the phone stays in a pocket. We never synthesize a decline on the user's behalf, and the sender's own timeout is the only thing that ends the wait.

Three rules make that safe:

1. **Navigating away never responds.** Not accept, not decline, not on backgrounding, not on timeout of our own.
2. **A live request is never lost.** While one is pending and the user is elsewhere, an `info` `StatusBanner` with an action slot sits on Home, naming the request and returning to the gate. Persistent, not a toast, and it does not go away on its own.
3. **The copy separates them.** Decline is worded as telling the other device no. Nothing on this screen describes leaving as an action, because it is not one.

`brand.md`'s rule holds throughout: nothing is accepted without an explicit yes.

---

## HistoryRow

One past transfer. Leading direction glyph at `--icon-size-md` (`arrow.up.circle` / `arrow.down.circle`), `--color-accent` when the transfer completed and `--color-text-secondary` otherwise, because a failed transfer is not an accent moment.

Title `--type-body`, middle-truncated, one line: the first filename, plus `+ N more` when there were others, or "Text snippet". Metadata row underneath at `--type-caption1` secondary, gap `--space-3`: relative date, size, then the code hint in `--font-mono`. Sizes and dates follow `content.md` → Numbers and Dates.

Trailing status glyph, `aria-label` carrying the status word because the glyph is the only thing that shows it:

| Status | Glyph | Color |
|---|---|---|
| completed | `checkmark.circle.fill` | `--color-status-success` |
| failed | `xmark.circle.fill` | `--color-status-error` |
| cancelled | `slash.circle` | `--color-text-secondary` |
| declined | `hand.raised.fill` | `--color-status-warning` |

This is the one place a status color appears without an adjacent word, so the accessibility label is not optional (`colors.md` rule 2, `accessibility.md` → Never color alone).

Row actions are `ContextMenu` on both platforms, plus swipe actions on iOS. Empty list is `EmptyState` with two actions.

---

## OnboardingSheet

First-run explainer, three points, then gone forever. **It is not a tour and never gains a pager.** Full detail lives on the How It Works screen, one tap deeper.

Centered column, gap `--space-7`, padding `--space-8`, capped at `--content-max-width`. Mark glyph at 56 in `--color-accent`. Title `--type-title2`. Three bullets at gap `--space-5`, each a leading glyph at `--icon-size-lg` in `--color-accent` with a `--type-headline` title and a `--type-callout` secondary body, gap `--space-4`.

Glyph frames use a **minimum** width, never a fixed one, or the glyph clips at accessibility text sizes.

Closing action is one full-width `prominent` large button.

Any system permission prompt is raised **after** this sheet dismisses, one at a time, never stacked behind it.

---

## HowItWorksList

The trust screen. Scrolling list of labelled paragraphs, gap `--space-6`, capped at `--content-max-width`. Each item: leading glyph at `--icon-size-lg`, title `--type-headline`, body `--type-callout` secondary, inner gap `--space-2`.

No card, no tint, no accent wash. This screen is the one that has to read as plain and true, so it is typography on the page fill and nothing else. Claims are capped by `content.md` → Claims.

---

## ScannerSheet

QR capture, iOS only. Sheet with a cancel-only header (`SheetHeader`) and the live camera filling the body.

Four states, four distinct copies, and they are not interchangeable:

| State | Body | Action |
|---|---|---|
| authorized and supported | live scanner | — |
| resolving permission | centered indeterminate `ProgressView` | — |
| denied | `EmptyState`, camera glyph | "Open Settings" |
| restricted, or unsupported hardware | `EmptyState`, camera glyph | **none** |

Restricted gets no Settings button on purpose: the user cannot fix it there, and a button that does nothing is worse than no button (`content.md` → Errors).

---

## SettingsForm

macOS Settings scene (⌘,), a grouped `Form` in sections, minimum 480×420. Not a screen inside the main window.

Default keyboard focus goes to a **real, visible button**, never to the first text field, or macOS opens the window with a blinking caret sitting in an address field.

Trailing values truncate in the middle so the tail of a path stays readable.

---

## Alert + ConfirmationDialog

System presentations, never custom-drawn. Reach for them in exactly two cases: a destructive action that cannot be undone, and a failure the user must acknowledge before continuing. Everything else is a `StatusBanner`.

- Title is a question for a confirmation ("Clear all history?"), a statement for a failure.
- Message is one sentence, sentence case, and says what will *not* happen as well as what will ("Removes the list only — received files stay where they are.").
- The destructive choice takes the destructive role; the safe choice is the cancel role and is what Return selects.
- Never more than two actions. Three means the screen needed a decision it did not make.

---

## ContextMenu + SwipeActions

Always additive. Every action in a context menu or a swipe is reachable another way, because neither is discoverable and neither exists for VoiceOver users the way it does for pointer users.

Destructive entries take the destructive role. A swipe's leading edge carries the constructive action and takes `--color-accent`; the trailing edge carries the destructive one.

---

## Icon

Rendering, sizes and stroke weights are `iconography.md`'s — this file only names which glyph a component uses.

---

## DiskImage

The macOS download's Finder window. Not an app surface, but it is the first CrocApp anyone sees, so it is specified here rather than improvised in a build script.

Window 660×400, icons 128, app at (165, 195), Applications alias at (495, 195). `scripts/build-dmg.sh` passes exactly these numbers to `create-dmg`; changing one without changing the other leaves this file lying.

Background `assets/dmg-background.png`, 660×400, `--color-surface-base`. Title "CrocApp" at `--type-title3` semibold, `--color-text-primary`, 44 from the top. Lucide `arrow-right` between the two icon slots at 44×44, stroke 1.5, `--color-separator`. Hint "Drag CrocApp onto Applications" at `--type-footnote`, `--color-text-secondary`, 38 from the bottom.

**Light values only.** Finder shows one fixed image and does not swap it with the system appearance, so the usual both-themes rule cannot apply. It is also 1x: `create-dmg` documents png, gif and jpg backgrounds, so there is no HiDPI representation and the image is soft on a Retina display (`docs/known-issues.md`).

No accent, no gradient, no mascot: `brand.md` keeps the accent off large background surfaces, and a first-run install window is the calmest thing in the product.
