# Components

Use the system control first. Apple ships it, so the app uses it and this file says which one and what to set; its geometry is Apple's. A component is drawn only when no system control does the job, and then it still takes sizes from the system text styles, `--space-*` and `--radius-*`, not from a pixel table. Each component's measurements live in its view as named constants.

Composition in the app: page (`--color-surface-grouped`), then cards and grouped lists, then controls, then buttons. On web the page is `--color-surface-base`. Every foreground obeys `principles.md`, "Contrast".

## States

Interactive elements share six states: rest, hover, pressed, focus, disabled, loading. Add a seventh only with a reason.

- **Hover** applies the pressed background and nothing else, only with a pointer. Web wraps it in `@media (hover: hover)`; the app takes the system's pointer effect.
- **Pressed** is the system style's own state in the app, and hover plus a slight scale on web.
- **Focus** is the system indicator in the app and `--shadow-focus-ring` on web.
- **Disabled** is `.disabled()` on controls. A row or field that dims as one takes `--opacity-disabled-container`.
- **Loading** has no skeletons. Known extent shows a determinate progress bar, unknown extent an indeterminate one. A working button keeps its label and width, swaps its leading glyph for a spinner and goes disabled; it never collapses to a bare spinner or resizes under the pointer.

## Shared: drawn on web, system-styled in the app

### Button

A capsule in Apple's prominent, bordered and borderless styles, with an optional glyph before or after the label, in three sizes (large `--control-height-lg`, medium, small). Labels are semibold, never wrap, and a small button still gets a `--hit-target-min` hit area.

| Variant | Use | Fill and label |
|---|---|---|
| `prominent` | the screen's one main action | `--color-accent-solid`, `--color-on-accent` |
| `secondary` | a supporting action | `--color-accent-tint`, accent text |
| `destructive` | Decline, confirming Clear History | `--color-status-error`, `--color-on-status` |
| `destructive-tinted` | Cancel transfer, Discard, small destructive actions | error tint, primary text |
| `plain` | tertiary actions and links in a row | none, accent text |

- Prefer at most one `prominent` per screen. A calm screen does not shout, so Cancel and Discard are `destructive-tinted`.
- `destructive-tinted` draws its label in primary text, never the error color; its leading glyph may keep the error color.
- A small filled button is not needed: a small accent or destructive action is `secondary` or `destructive-tinted`.
- In the app the variants are one modifier each in `app/CrocApp/Views/ButtonVariants.swift`. A `Button(role: .destructive)` never ships with the default style, which paints its label in the status color.

### Card (GlassCard)

The default content container: `--color-surface-card`, `--radius-lg`, a hairline `--color-separator` border (in light, card and page are both white, so the border is the separation) and `--space-6` padding. An elevated card adds `--shadow-sm`; a tinted card (`--color-accent-tint`) is for the one card that reads as the answer. In the app use grouped `List` or `Form` sections, or `.glassEffect()` on a floating surface. There is no hand-built card view.

### TrustBadge

End-to-end encryption reassurance. The **pill** is an inline capsule on the status-success tint with a primary label and a `lock` glyph; it appears on the landing hero, the Home header and the accept gate. The **full** variant is a row card with a solid success circle holding a knocked-out `checkmark.shield.fill`, and tops How It Works. The pill's label is primary text because success on its own tint is 1.98:1. Copy stays within `voice.md`, "Claims".

---

## Drawn in the app

### DropZone

The empty send target: the Send screen's staging area, the menu bar window and the macOS window overlay. At rest it is a dashed `--color-separator` stroke on `--color-fill-tertiary` at `--radius-lg`, with a glyph, a headline and a hint. While a drag is over it the stroke goes solid `--color-accent` and the fill `--color-accent-tint`, with no scale. The macOS overlay dims the window with `--color-scrim` and shows a centered `.glassEffect()` card holding "Drop to Send".

**A drop target is not an input.** Every DropZone ships beside a real file-picker button. On Send, the staged list replaces the zone and the Files tab does not change height as files arrive: the list and the text editor keep the zone's height as a floor and grow to a cap, then scroll.

### CodeField

Monospaced entry for `word-word-word`, wherever a code phrase is typed. Mono at the code-body style with `--tracking-code`, no autocapitalization, autocorrection or spell check, and the system `PasteButton` trailing. The border is `--color-separator` idle, `--color-accent` focused and `--color-status-error` invalid. Invalid shows a one-line footnote under the field and never the word "invalid". A code that is still too short is unfinished, not wrong: the border and message wait until Return or the field is left, and clear as soon as the value is right.

### CodePhraseDisplay and QRFrame

The sender's waiting state, a centered column: the eyebrow "READY TO SEND", the code in the hero mono style (selectable, wraps only between words, optionally on a `.glassEffect()` pill), a `secondary` **Copy Code** button that flips to a check and "Copied" for two seconds (symbol replace, `.selection` haptic), the QR frame, and an optional caption. The QR frame is always white because scanners need it, with a hairline border and `--shadow-md`. Its payload is the receive link `https://crocapp.dev/r/#<code>` from `TransferLink.webURL(forCode:)`. The menu bar window shows the code at title3 size because its column is narrow.

### TransferProgress

A direction header (`arrow.up` or `arrow.down` plus the word **Sending** or **Receiving**, both always), then the current file (middle-truncated name, bar, `File N of M`, `done / size`) and the overall bar with the live speed. Unknown or zero speed shows an em-dash placeholder. Captions are caption1 secondary and every number is tabular. Bars are system `ProgressView`, animated gently and never backwards. While the sender waits for the other device the arrow pulses, and only then.

### StatusBanner

Inline advisory on the kind's tint with a hairline border. The glyph carries the kind (`info.circle`, `exclamationmark.triangle.fill`, `exclamationmark.circle.fill`, `checkmark.circle`); the title is subhead semibold in **primary** text and the body footnote secondary, with an optional trailing `plain` action. Only error banners are announced. A banner appears by fading in as it moves down into its slot.

### StatusBlock

The large centered result (done, failed): a circle in the kind tint holding a glyph in the kind color, a title, a one-sentence detail, then full-width large actions stacked. The title states the outcome in words; the glyph only repeats it. A failure is a short title, one sentence of detail and at most two actions chosen by the kind of failure, and **Done** is always one of them.

| Failure kind | Actions |
|---|---|
| Worth another try: the same inputs could now succeed (connection dropped, relay unreachable, iOS paused the transfer) | **Try Again** `prominent`, **Done** `secondary` |
| A setting is the cause (relay password rejected, local network access off) | **Open Settings** `prominent`, **Done** `secondary` |
| Retrying would not help (the other device declined, codes do not match, link expired) | **Done** `prominent`, alone |

**Try Again** re-runs the same transfer with the same inputs, so it never appears when the user must change something. **Open Settings** goes where the fix lives: CrocApp's Settings for ours, the system's for a permission. A button that will not help is never offered. A failure fires the `.error` haptic and is announced. Copy: `voice.md`, "Errors".

### AcceptGate

The incoming request, shown as a phase of the transfer screen, never a sheet or an alert, so it cannot be dismissed by accident. It lists the files, banners any overwrite conflict or blocked item, and offers Decline (`destructive`) and Accept (`prominent`). There is no Cancel and no "Not now": leaving the screen answers nothing and the request stays live, with a Review banner and badge so it is never lost. Behavior and the full rules: `docs/knowledge/app-ui-architecture.md`, "Accept gate".

### FileRow

A send-queue and accept-gate row: a type glyph (`folder`, `photo`, `doc.text`, `doc`) in the accent, the filename **middle-truncated** so the extension stays visible, and the size in footnote secondary, tabular. The send queue adds a remove control (`xmark.circle.fill`, labelled "Remove <name>", with a full hit area). A received row is one button that opens Quick Look, labelled "Quick Look <name>", with a trailing `ShareLink`; it drags out as the file and its context menu holds Quick Look, Share and Show in Finder or Files. Details: `docs/knowledge/app-ui-architecture.md`, "System surfaces".

### HistoryRow

One past transfer: a direction glyph (accent when completed, secondary otherwise), a middle-truncated title (the first filename plus "+ N more", or "Text snippet"), and caption metadata with the relative date, size and code hint in mono (`voice.md`, "Numbers"). The status glyph is the one place a status color appears without an adjacent word, so its accessibility label is mandatory.

| Status | Glyph | Color |
|---|---|---|
| completed | `checkmark.circle.fill` | success |
| failed | `xmark.circle.fill` | error |
| cancelled | `slash.circle` | secondary |
| declined | `hand.raised.fill` | error |

Actions are a context menu everywhere and swipe on iOS. An empty list is an EmptyState with a Send and a Receive action; with Save Transfer History off it says "History is off" with an **Open Settings** button instead. A row opens its record as a grouped `Form` that shows only what the record holds, then the actions the context menu already offers.

### Home

The compact root: one column capped at `--content-max-width`, in a grouped `Form`, so the page fill, section and scrolling are the system's. In order: the TrustBadge pill, the pending-request banner (only while a request waits), the two actions (Send `prominent`, Receive `secondary`, large and full width, glyph in `.fill`), then **Recent transfers**, always below the actions.

Recent transfers are up to three records, newest first, each a HistoryRow cut to a glance: direction glyph, a one-line title ("3 files" when several), the relative date, and a leading status word when the record did not complete. A tap opens the record in History, and the row speaks as one label ("Sent 3 files, yesterday"). With no history an EmptyState replaces the section ("No transfers yet", no button, because the two actions above are the actions). With Save Transfer History off the section is hidden, not empty, since an empty state would promise rows that never come. At accessibility sizes the page scrolls and the two actions stay first.

### SidebarRow

Regular width only: a system sidebar row whose trailing state is ours, and only on the row of the active transfer's direction. The state is words first: "Connecting", "Waiting", a **Review** badge (capsule `--color-accent-solid`, label `--color-on-accent`) while an answer is needed, or the integer percent while transferring (the direction word when the total is unknown). The row speaks one label ("Send, 42 percent"), a change is announced once per phase and never per progress tick, and the app never selects a row or changes the detail on its own. Contrast of the state text on the sidebar material is the system's to keep (not verified).

### OnboardingSheet

First-run explainer: three points, then gone forever. Never a tour or a pager. A mark glyph, a title and three bullets (glyph, headline, secondary body), then one full-width large `prominent` button. Glyph frames take a minimum width with headroom so every bullet's text starts at one x, the column scrolls at large sizes, and at accessibility sizes each bullet's glyph sits above its text. System permission prompts come after it dismisses, one at a time. The mascot may appear here.

### HowItWorksList

The trust screen: TrustBadge `full` on top, then labelled paragraphs (glyph, headline, secondary body) within `--content-max-width`. No card, tint or wash beyond the badge: this screen has to read plain and true. Claims are capped by `voice.md`, "Claims".

### ScannerSheet

QR capture, iOS only: a sheet with a Cancel-only toolbar and the live camera, with a one-line hint on a `.glassEffect()` pill. Denied, restricted, unsupported and starting states are an EmptyState (`video.slash`), with **Open Settings** only where Settings can fix it. A QR code that is neither a code phrase nor a link shows an error StatusBanner ("That isn't a CrocApp QR code", "Scan the QR code on the sending device.") and the scanner keeps running; only the first code phrase or link closes the sheet.

### MenuBarQuickSend

The macOS menu bar window: a compact DropZone, the code in mono, one progress bar with the direction header, and the same buttons as the main window. Everything it does, the main window does too.

---

## System controls

| Component | App | Notes |
|---|---|---|
| SegmentedControl | `Picker` + `.pickerStyle(.segmented)` | segment labels Title Case |
| Toggle | `Toggle` | system tint, no custom switch |
| Sidebar | `NavigationSplitView` sidebar, `List(selection:)` of `Label` rows | the system's style, selection, material and width; the trailing state is SidebarRow |
| Settings rows | `Form` + `.formStyle(.grouped)`, `LabeledContent`, `Toggle`, `Picker`, `NavigationLink` | trailing paths truncate in the middle; a footer we write takes `--color-text-secondary` explicitly |
| Settings scene | macOS `Settings` scene (⌘,), the same `Form` | default focus on a real button, never a text field |
| Sheet toolbar | `.toolbar` with `.cancellationAction` and `.confirmationAction` | a destructive confirm is labelled by the sheet's copy, not painted red |
| ProgressBar | `ProgressView(value:total:)`, indeterminate `ProgressView()` | see TransferProgress |
| EmptyState | `ContentUnavailableView` | glyph secondary, one-sentence description in `--color-text-secondary` |
| Alert, ConfirmationDialog | system presentations | only for an irreversible destructive action or a failure the user must acknowledge; everything else is a StatusBanner. A confirmation title is a question, a failure title a statement. At most two actions, the destructive one in the destructive role and the safe one in the cancel role |
| ContextMenu, SwipeActions | `.contextMenu`, `.swipeActions` | additive: every action is reachable another way. A swipe's leading edge is constructive, its trailing edge destructive. An entry that only asks first (Revoke) takes the error tint instead of the destructive role, or SwiftUI animates the row away |
| Share | `ShareLink` | |

Glyph names for each component are in `implementation.md`, "Icons".
