# Components

The app's own pieces: what is drawn because no system control does the job, and the behavior of the screens built from them. Styling is the system's (`principles.md`, "Controls"); this file says what each piece does.

## DropZone

The empty send target: the Send screen's staging area, the menu bar window and the macOS window overlay. A glyph, a headline and a hint; while a drag is over it the state changes by color, with no scale.

**A drop target is not an input.** Every DropZone ships beside a real file-picker button. On Send, the staged list replaces the zone, and the list and the text editor keep the zone's height as a floor and grow to a cap, then scroll.

## CodeField

Monospaced entry for `word-word-word`, wherever a code phrase is typed: no autocapitalization, autocorrection or spell check, and the system `PasteButton` trailing. Invalid shows a one-line footnote under the field and never the word "invalid". A code that is still too short is unfinished, not wrong: the message waits until Return or the field is left, and clears as soon as the value is right.

## CodePhraseDisplay and QRFrame

The sender's waiting state: the eyebrow "READY TO SEND", the code in the hero mono style (selectable, wraps only between words), a **Copy Code** button that flips to a check and "Copied" for two seconds (`.selection` haptic), the QR frame, and an optional caption. The QR frame is always white because scanners need it. Its payload is the receive link `https://crocapp.dev/r/#<code>` from `TransferLink.webURL(forCode:)`.

## TransferProgress

A direction header (`arrow.up` or `arrow.down` plus the word **Sending** or **Receiving**, both always), then the current file (middle-truncated name, bar, `File N of M`, `done / size`) and the overall bar with the live speed. Unknown or zero speed shows an em-dash placeholder, and every number is tabular. Bars are system `ProgressView` and never go backwards.

## StatusBlock

The result (done, failed), top-aligned: a glyph in the kind color, a title that states the outcome in words and a one-sentence detail. Its actions sit in the actions row at the bottom of the screen, with the prominent one last. A failure has at most two actions chosen by the kind of failure, and **Done** is always one of them.

| Failure kind | Actions |
|---|---|
| Worth another try: the same inputs could now succeed (connection dropped, relay unreachable, iOS paused the transfer) | **Try Again** primary, **Done** |
| A setting is the cause (relay password rejected, local network access off) | **Open Settings** primary, **Done** |
| Retrying would not help (the other device declined, codes do not match, link expired) | **Done** primary, alone |

**Try Again** re-runs the same transfer with the same inputs, so it never appears when the user must change something. **Open Settings** goes where the fix lives: CrocApp's Settings for ours, the system's for a permission. A button that will not help is never offered. A failure fires the `.error` haptic and is announced. Copy: `voice.md`, "Errors".

## AcceptGate

The incoming request, shown as a phase of the transfer screen, never a sheet or an alert, so it cannot be dismissed by accident. It lists the files, banners any overwrite conflict or blocked item, and offers Decline (destructive) and Accept (primary) in the actions row at the bottom, so a long list scrolls above them. There is no Cancel and no "Not now": leaving the screen answers nothing and the request stays live, with a Review badge so it is never lost. Its direction header says **Review**, not **Receiving**, because nothing is received before the yes. Behavior and the full rules: `docs/knowledge/app-ui-architecture.md`, "Accept gate".

## HistoryRow

One past transfer: a direction glyph, a middle-truncated title (the first filename plus "+ N more", or "Text snippet"), and the relative date, size and code hint in mono. The status glyph is the one place a status color appears without an adjacent word, so its accessibility label is mandatory.

| Status | Glyph | Color |
|---|---|---|
| completed | `checkmark.circle.fill` | success |
| failed | `xmark.circle.fill` | error |
| cancelled | `slash.circle` | secondary |
| declined | `hand.raised.fill` | error |

An empty list says "History is off" with an **Open Settings** button while Save Transfer History is off, and otherwise offers Send and Receive.
