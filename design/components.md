# Components

Every component on every surface. Two kinds:

- **System controls.** Apple ships them, so the app uses them and this file says only which one and what we set (`AGENTS.md` rule 2). Their geometry is Apple's.
- **Drawn components.** No system control does the job, so the measurements here are exact. They come from this file, not from eyeballing a render; keep them as constants in the component, never scattered at call sites.

Composition in the app: page (`--color-surface-grouped`), then cards and grouped lists, then controls, then buttons. On the web the page is `--color-surface-base` (`web.md` → Page fill).

Every foreground obeys `colors.md` → Contrast. Two rules decide most of this file: **accent never labels anything** (labels take `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and tint), and **a status color is a fill, never a foreground** (status text is `--color-text-primary`; the tint carries the meaning).

---

## States

Every interactive element has the same six states. A component that needs a seventh needs a reason written down.

| State | Web | App |
|---|---|---|
| rest | the variant's values | the variant's values |
| hover | the variant's pressed background, nothing else: no scale, lift, color or shadow change. `--dur-fast` `--ease-standard`, inside `@media (hover: hover)` | the system's pointer effect (macOS, iPad with a pointer) |
| pressed | hover plus `scale(var(--press-scale-web))`, `--dur-fast` `--ease-out` | the system style's own pressed state |
| focus | `--shadow-focus-ring`, replacing the variant's shadow | the system focus indicator |
| disabled | `--opacity-disabled-container` on rows and fields | `.disabled()` on controls; rows and fields that dim as one take `--opacity-disabled-container` |
| loading | below | below |

Hover is pointer-only and nothing may be discoverable only on hover (`platforms.md` → Hover). A text link may also underline on hover; that restates, it does not reveal.

**Loading.** No skeletons. Known extent shows a determinate progress bar; unknown extent shows an indeterminate one. A working button keeps its label and width, swaps its leading glyph for a spinner, and goes disabled. It never collapses to a bare spinner and never resizes under the pointer.

---

## Shared: drawn on web, system-styled in the app

### Button

Capsule, Apple prominent style, icon before and/or after the label.

| Size | Height | Padding | Font | Gap | Icon |
|---|---|---|---|---|---|
| large | `--control-height-lg` 50 | `0 22px` | `--type-headline` 17 | 8 | 20 |
| medium | `--control-height-md` 38 | `0 16px` | `--type-callout` 16 | 6 | 18 |
| small | `--control-height-sm` 30 | `0 12px` | `--type-footnote` 13 | 5 | 15 |

Always `--weight-semibold`, `--tracking-headline`, `line-height: 1`, `--radius-capsule`, no wrapping. A bare small button still gets a `--hit-target-min` hit area.

| Variant | Background | Label | Border | Pressed |
|---|---|---|---|---|
| `prominent` | `--color-accent` | `--color-on-accent` | none | `--color-accent-pressed` |
| `secondary` | `--color-accent-tint` | `--color-accent-text-on-tint` | none | `color-mix(in srgb, var(--color-accent) 12%, var(--color-accent-tint))` |
| `destructive` | `--color-status-error` | `--color-on-status` | none | `color-mix(in srgb, var(--color-status-error) 82%, black)` |
| `destructive-tinted` | `--color-status-error-tint` | `--color-text-primary` | 22% error | `color-mix(in srgb, var(--color-status-error) 12%, var(--color-status-error-tint))` |
| `plain` | none | `--color-accent-text` (`-on-tint` on grouped; always `-on-tint` in the app) | none | `--color-fill-tertiary` |

`prominent` and `destructive` carry `--shadow-sm` on web.

- `prominent` (3.41:1) and `destructive` (3.55:1) are the filled-button deviation (`colors.md` rule 3). **There is no small filled button**: a small accent or destructive action is `secondary` or `destructive-tinted`.
- `destructive-tinted` never draws its label in the error color (2.94:1). The tint and border say "destructive"; the leading glyph may stay `--color-status-error`.
- Usage: at most one `prominent` per screen. Filled `destructive` only for Decline (the accept gate) and confirming Clear History. Cancel transfer and Discard are `destructive-tinted`: they sit on screens the user watches for a while, and a calm screen does not shout. Everything else that is secondary is `secondary` or `plain`.

App: one modifier per variant in `app/CrocApp/Views/ButtonVariants.swift`, built on `.borderedProminent`, `.bordered` and `.borderless` (`swiftui.md` → Components). Views never style a button ad hoc, and a `Button(role: .destructive)` never ships with the default style, which paints its label in the status color.

### Card (GlassCard)

The default content container. Web: `.card`, fill `--color-surface-card`, `--radius-lg`, padding `--space-6`, border `var(--border-hairline) solid var(--color-separator)`. In light, card and page are both white, so the border is the separation; in dark the tonal step does it. `.card--elevated` adds `--shadow-sm`. `.card--tinted` swaps the fill for `--color-accent-tint`: for the one card that reads as the answer, never as decoration.

App: grouped `List`/`Form` sections, or `.glassEffect()` on a floating surface. There is no hand-built card view.

### TrustBadge

End-to-end-encryption reassurance.

- `pill`: inline capsule, fill `--color-status-success-tint`, label `--color-text-primary`, padding `--pill-pad-block-web` / `--pill-pad-inline-start-web` `--pill-pad-inline-end-web`, `--type-footnote` semibold, `lock` at 14 in `--color-status-success`. On the landing hero, the Home header and the accept gate.
- `full`: row card, `--radius-md`, success tint, 22% success border, a 34 solid-success circle holding a `--paper` `checkmark.shield.fill` at 19, label `--type-subhead` semibold plus an optional `--type-footnote` detail. Tops the How It Works screen.

The pill's label is primary because success on its own tint is 1.98:1. The `full` variant inverts instead: a solid fill with the glyph knocked out. Copy is capped by `content.md` → Claims.

---

## Drawn in the app

### DropZone

The empty send target: the Send screen's staging area, the menu bar window, and the macOS window overlay.

Idle: `--radius-lg`, 2pt dashed `--color-separator` stroke, fill `--color-fill-tertiary`, min height 168, centered column at gap `--space-4`: `square.and.arrow.up` at 44 in `--color-text-secondary`, title `--type-headline` primary, hint `--type-subhead` secondary.

Drag-over: stroke 2pt solid `--color-accent`, fill `--color-accent-tint`, glyph and title `--color-accent-text-on-tint`. `--dur-fast` `--ease-out`; no scale.

macOS overlay: the whole window takes `--color-scrim`, and a centered `.glassEffect()` card at `--radius-2xl` holds the glyph and "Drop to Send". The Send list's own drop target wins while the pointer is over it.

**A drop target is not an input.** Every DropZone ships beside a real file-picker button.

### CodeField

Monospaced entry for `word-word-word`, used everywhere a code phrase is typed, including a custom code on Send.

Wrapper: height `--control-height-lg`, padding `0 6px 0 14px`, fill `--color-surface-base`, `--radius-md`, `--border-hairline` border: `--color-separator` idle, `--color-accent` focused, `--color-status-error` invalid. Disabled dims to `--opacity-disabled-container`.

Input: `--font-mono` at `--type-code-body`, `--tracking-code`, no autocapitalization, autocorrection or spell check. Trailing system `PasteButton`, seated in the wrapper's 6px trailing inset. The system owns its glyph and its size: SwiftUI exposes only its border shape, label style and tint. Invalid shows a one-line `--type-footnote` message under the field, never the word "invalid".

### CodePhraseDisplay and QRFrame

The sender's waiting state. Centered column, gap `--space-5`:

1. Eyebrow "READY TO SEND": `--type-footnote`, semibold, `--tracking-eyebrow`, uppercase, secondary.
2. The code: `--type-code-hero` bold mono, `--tracking-code`, selectable, wraps only between words. It may sit on a `.glassEffect()` pill at `--radius-xl`.
3. Copy button, `secondary`: glyph `doc.on.doc` and label "Copy Code", flipping to `checkmark` and "Copied" for two seconds after a copy.
4. QR frame: 168 square, always white (scanners need it), `--radius-md`, 12 padding, `--shadow-md`, hairline `--color-separator` border. Payload: the receive link `https://crocapp.dev/r/#<code>` from `TransferLink.webURL(forCode:)`, which opens the app through the universal link or the browser receive page.
5. Optional caption, `--type-callout` secondary, at most 320 wide.

The menu bar window shows the same code at `--type-title3` mono semibold, because its column is 300 wide.

### TransferProgress

- **Direction header**: `arrow.up` or `arrow.down` at `--icon-size-sm` in `--color-accent`, plus the word **Sending** or **Receiving** in `--type-headline`. Both change together and neither is optional. A Send-as-link transfer says Sending and Receiving too.
- Current file: middle-truncated name (`--type-callout`), bar, caption row `File N of M` and `done / size`.
- Overall: bar, caption row `done / size` and the live speed in `--weight-medium` primary. Unknown or zero speed shows an em-dash placeholder.

Captions `--type-caption1` secondary. Every number is tabular (`.monospacedDigit()`). Bars are system `ProgressView`, animated at `--dur-base` `--ease-out`, never backwards.

### StatusBanner

Inline advisory. Padding `--space-4 --space-5`, gap `--space-3`, `--radius-md`, fill = kind tint, `--border-hairline` border at 22% of the kind color.

| Kind | Color | Glyph | Announced |
|---|---|---|---|
| info | `--color-status-info` | `info.circle` | no |
| warning | `--color-status-warning` | `exclamationmark.triangle.fill` | no |
| error | `--color-status-error` | `exclamationmark.circle.fill` | yes |
| success | `--color-status-success` | `checkmark.circle` | no |

Glyph at 19 in the kind color, decorative (`colors.md` rule 2). Title `--type-subhead` semibold **primary**; body `--type-footnote` secondary. Optional trailing action, `plain`.

### StatusBlock

Large centered result (done, failed). A 64 circle in the kind tint holding a 34 glyph in the kind color, then the title `--type-title3` semibold primary, then detail `--type-callout` secondary. Padding `--space-6`, gap `--space-3`. The title states the outcome in words; the glyph only repeats it.

### AcceptGate

The incoming request. Not a sheet and not an alert: a phase of the transfer screen, so it cannot be dismissed by accident.

Composition: direction header (Receiving), TrustBadge pill, the file list as `FileRow`s (no remove control), a `StatusBanner` for each of overwrite conflicts and blocked-unsafe items, then the actions: Decline `destructive`, Accept `prominent` (Keep Both and Replace when a name is taken). Nothing auto-advances and nothing is preselected.

**Two answers and one silence.**

| Exit | What the other device learns | What we do |
|---|---|---|
| Decline | that you said no | respond, then terminal phase |
| Accept | that you said yes | respond, then transfer |
| Navigating away | nothing | nothing. The request stays live |

There is no Cancel and no "Not now" here: either would answer the sender on the user's behalf or promise a deferral the protocol cannot deliver. The sender's own timeout is the only thing that ends the wait.

1. **Navigating away never responds**: not on backgrounding, not on a timeout of our own.
2. **A live request is never lost.** While one is pending and the user is elsewhere, an `info` StatusBanner with a Review action sits on Home and returns to the gate. Persistent, not a toast.
3. **The copy separates them.** Decline is worded as telling the other device no. Nothing describes leaving as an action.

Auto-accept, when the user turns it on in Settings, skips this gate; it is off by default on every platform (`platforms.md`).

### FileRow

Send queue and accept-gate row. Min height 48, padding `--space-3 --space-4`, gap `--space-3`.

Type glyph at 20 in `--color-accent`: `folder`, `photo`, `doc.text`, `doc`. Filename **middle-truncated** with the last 8 characters pinned so the extension stays visible. Size `--type-footnote` secondary, tabular. Remove control (send queue only): `xmark.circle.fill` at 20, `--color-text-secondary`, labelled "Remove <name>", with a `--hit-target-min` hit area.

### HistoryRow

One past transfer. Leading direction glyph at `--icon-size-md` (`arrow.up.circle`, `arrow.down.circle`): `--color-accent` when completed, `--color-text-secondary` otherwise.

Title `--type-body`, middle-truncated: the first filename plus "+ N more", or "Text snippet". Metadata at `--type-caption1` secondary, gap `--space-3`: relative date, size, the code hint in mono. Formats per `content.md` → Numbers and Dates.

| Status | Glyph | Color |
|---|---|---|
| completed | `checkmark.circle.fill` | `--color-status-success` |
| failed | `xmark.circle.fill` | `--color-status-error` |
| cancelled | `slash.circle` | `--color-text-secondary` |
| declined | `hand.raised.fill` | `--color-status-error` |

The status glyph is the one place a status color appears without an adjacent word, so its accessibility label (the status word) is mandatory. Actions: context menu everywhere, swipe on iOS (System controls → ContextMenu, SwipeActions). Empty list is an EmptyState with a Send and a Receive action.

### OnboardingSheet

First-run explainer: three points, then gone forever. Never a tour, never a pager.

Centered column, gap `--space-7`, padding `--space-8`, capped at `--content-max-width`. Mark glyph `arrow.left.arrow.right.circle.fill` at 56 (scaled with Dynamic Type) in `--color-accent`. Title `--type-title2`. Three bullets at gap `--space-5`: glyph at `--icon-size-lg` in `--color-accent`, `--type-headline` title, `--type-callout` secondary body, gap `--space-4`. Glyph frames take a minimum width, never a fixed one. One full-width large `prominent` button closes it. System permission prompts come after it dismisses, one at a time.

### HowItWorksList

The trust screen. TrustBadge `full` on top, then labelled paragraphs at gap `--space-6`, capped at `--content-max-width`: glyph at `--icon-size-lg`, title `--type-headline`, body `--type-callout` secondary, inner gap `--space-2`. No card, tint or accent wash beyond the badge: this screen has to read plain and true. Claims capped by `content.md` → Claims.

### ScannerSheet

QR capture, iOS only: a sheet with a Cancel-only toolbar and the live camera.

| State | Body | Action |
|---|---|---|
| authorized and supported | live scanner | none |
| resolving permission | indeterminate `ProgressView` | none |
| denied | EmptyState, `video.slash` | "Open Settings" |
| restricted, unsupported or failed to start | EmptyState, `video.slash` | none |

No Settings button where Settings cannot fix it (`content.md` → Errors).

### MenuBarQuickSend

macOS menu bar window, 300 wide: a compact DropZone (min height 96), the code at `--type-title3` mono, one progress bar with the direction header, and the same buttons as the main window. Everything it does, the main window does too.

### DiskImage

The macOS download's Finder window. Not an app surface, but the first CrocApp anyone sees.

Window 660×400, icons 128, app at (165, 170), Applications alias at (495, 170). `scripts/build-dmg.sh` passes exactly these numbers to `create-dmg`.

Background `assets/dmg-background.tiff`: a 1x and 2x multi-representation TIFF (`tiffutil -cathidpicheck bg.png bg@2x.png -out dmg-background.tiff`), fill `--bg-secondary` dark. Positions are centers, measured from the image top, which Finder draws under the 32pt title bar:

| Element | Spec | Center y |
|---|---|---|
| Title "CrocApp" | `--type-title3` semibold, `--label-1` dark | 44 |
| Lucide `arrow-right`, midway between the icons | 44×44, stroke 1.5, `--label-2-web` dark | 170 |
| Label plates, one under each icon | 140×26, radius 13, `rgba(235,235,245,0.85)` | 254 |
| Hint "Drag CrocApp onto Applications" | `--type-footnote`, `--label-2-web` dark | 316 |

**Dark only, with label plates.** Finder shows one fixed image regardless of appearance, and with a background picture set it draws icon labels black in both appearances (verified on macOS 27). The plates keep those black labels readable on the dark fill; a plate center sits 84pt below its icon center, where Finder puts a 128pt icon's label. Keep everything inside the top 340pt: Finder clips at about 368pt under the title bar, 340 with the path bar on. No accent, gradient or mascot.

---

## System controls

| Component | App | Notes |
|---|---|---|
| SegmentedControl | `Picker` + `.pickerStyle(.segmented)` | segment labels Title Case |
| Toggle | `Toggle` | system tint; no custom switch |
| Settings rows | `Form` + `.formStyle(.grouped)`, `LabeledContent`, `Toggle`, `Picker`, `NavigationLink` | trailing paths truncate in the middle |
| SettingsForm | macOS Settings scene (⌘,), the same `Form` | default focus on a real visible button, never a text field. Advanced, Power and About are sections of it |
| Sheet toolbar | `.toolbar` with `.cancellationAction` / `.confirmationAction` | a destructive confirm is labelled by the sheet's copy, not painted red |
| ProgressBar | `ProgressView(value:total:)`; indeterminate `ProgressView()` | see TransferProgress |
| EmptyState | `ContentUnavailableView` | glyph secondary, description one sentence |
| Alert, ConfirmationDialog | system presentations | only for an irreversible destructive action or a failure the user must acknowledge; everything else is a StatusBanner. A confirmation title is a question ("Clear all history?"), a failure title a statement. One sentence of message saying what will and will not happen. Destructive choice takes the destructive role, the safe choice is the cancel role. Never more than two actions |
| ContextMenu, SwipeActions | `.contextMenu`, `.swipeActions` | always additive: every action is reachable another way. An entry that removes the row takes the destructive role; one that only asks first (Revoke) takes `--color-status-error` as its tint instead, or SwiftUI animates the row away. A swipe's leading edge is constructive, its trailing edge destructive |
| Share | `ShareLink` | |

Glyphs, sizes and strokes for every component are `iconography.md`'s.
