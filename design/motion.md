# Motion and feedback

How the interface changes and how it answers back. What a surface is made of is `materials.md`.

## Motion

| Token | Value | Use |
|---|---|---|
| `--ease-standard` | `cubic-bezier(0.4, 0, 0.2, 1)` | color and background changes, hover |
| `--ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | entrances, cross-fades, position, progress fills |
| `--dur-fast` | 120ms | press feedback, hover, drag-over |
| `--dur-base` | 220ms | phase cross-fade, progress |
| `--dur-slow` | 360ms | the slow-connection hint |
| `--press-scale-web` | 0.97 | web buttons shrink slightly when pressed |

The app takes press feedback from the system button styles and adds no scale of its own, which is why the press scale is web-only.

**No springs, no bounce, no overshoot.** Neither curve passes y = 1. Skills and samples that reach for `.spring` or a bouncy curve are overruled here: a transfer screen that performs is a transfer screen you do not trust.

Under `prefers-reduced-motion` and `.accessibilityReduceMotion`: no press scale, no indeterminate slide (hold a static fill), and every state change stays, instant rather than removed. `tokens.css` zeroes the durations and the press scale; a looping animation is its component's own to gate. In SwiftUI, pass `nil` instead of an animation when reduce motion is on.

## Vocabulary

Four motions beyond the phase cross-fade are allowed, each for one job. Nothing else moves: no bounce, no overshoot, no spring (so none with visible overshoot either), no stagger or cascade, and no loop that is decoration. Two of the four are SF Symbols effects the system draws, so we pass them no animation of our own and use only the two named here: no `.bounce`, `.wiggle` or any other.

| Motion | Job | Timing | Reduce Motion |
|---|---|---|---|
| **Symbol replace**: `contentTransition(.symbolEffect(.replace))` | One glyph becomes another in the same place: Copy to Copied (`doc.on.doc` to `checkmark`) | the system's replace effect | the glyph swaps instantly (`.contentTransition(.identity)`); the label still changes |
| **Numeric text**: `contentTransition(.numericText())` | A number changes in place: the progress percent, the live speed, "File 3 of 12", the percent in a SidebarRow | `--dur-base` `--ease-out` on the value | the digits swap instantly |
| **Insert**: opacity plus a `--space-3` move | A StatusBanner or a list row appears. It fades in while travelling `--space-3` down into place from above | `--dur-base` `--ease-out`. Removal is opacity only, `--dur-fast` `--ease-standard` | appears and disappears instantly |
| **Pulse**: `symbolEffect(.pulse)` | The direction glyph while the sender waits for the other device (phase `waiting`), and only then | the system's pulse, active only in that phase | no effect: a static glyph |

1. **Each one decorates a change that already happened.** The Copy button already says "Copied", the number is already the new number, the banner is already there, "Waiting" is already in words. Reduce Motion removes the movement and keeps every change (the rule above), so nothing here is ever the only signal.
2. **Insert never moves a persisting element.** A banner takes the slot below the direction header, trust badge and code phrase, so choreography rule 2 holds. A row inserted into a list moves the rows below it, which is what a list does.
3. **Numbers stay put.** Numeric text is always tabular (`typography.md`). A readout that changes faster than once a second, the speed, shows a new value at most once a second: a roll that restarts five times a second reads as a blur. Progress never counts down (below).
4. **One pulse per window**, never on a button or a control, and it stops the moment the phase leaves `waiting`. It is the only loop we add, and it is not decoration: it says the app is alive and waiting. It is not announced.
5. **Symbol replace reverts the same way**: Copied returns to Copy Code after two seconds with the same transition.

## Choreography

A transfer is a phase machine, and the transitions between phases are the product: `idle → starting → waiting / connecting → confirmSend | incoming → transferring → done | failed | stored`.

1. **The phase container cross-fades; its contents do not animate in separately.** One `--dur-base` `--ease-out` opacity transition on the block that swaps. No stagger, no cascade.
2. **What persists must not move.** The direction header, the trust badge and the code phrase keep their position across every phase that shows them. A code phrase that jumps when the transfer starts is the worst thing this screen can do, because it is what the user is reading aloud.
3. **Terminal phases arrive, they do not celebrate.** `done` and `failed` cross-fade in like any other phase. The StatusBlock glyph does not pop, spin or bounce, and there is no confetti (`brand.md` → Personality).

Progress fills animate width at `--dur-base` `--ease-out` and **never move backwards**. If a total revises downward, snap and keep moving forward.

The "taking longer than usual" hint fades in at `--dur-slow`, after the delay that triggers it, so it reads as information rather than alarm.

## Haptics and sound

**No sound, ever.** A file transfer that beeps in a meeting is a file transfer people turn off. That includes notifications: none sets a sound (`platforms.md` → System surfaces).

Haptics are iPhone only: iPad's are inconsistent across models and macOS has none. They are always additive: every event below is already visible and announced.

| Event | Feedback | Already visible and announced as |
|---|---|---|
| transfer completed | `.success` | the done StatusBlock |
| transfer failed, declined by the other device, or blocked | `.error` | the failure StatusBlock, announced |
| incoming request arrives (the accept gate) | `.warning` | the gate, or the Review banner on Home, or the Review badge in the sidebar |
| a copy succeeded: code phrase, link or text | `.selection` | the Copy button flips to a check and "Copied" for two seconds (`components.md` → CodePhraseDisplay), announced "Copied" |
| a QR scan decoded a code phrase or a link | `.selection` | the scanner closes and the field fills, announced "Code scanned" or "Link scanned" |

Five events, and no more without a reason written down. `.success`, `.warning` and `.error` belong to what happens to a transfer; `.selection` is for a value captured. A copy from a context menu has no visible flip, so it fires nothing: no haptic without something to see. Nothing fires on progress, phase changes inside a running transfer, ordinary button presses or navigation, so a Cancel or Decline the user tapped ends silently.

The **Haptics** setting (Settings, iPhone only, on by default) gates all five. Off means none, and every event stays visible and announced. The system's own haptic setting is respected too, because feedback goes through `.sensoryFeedback` (`swiftui.md` → Motion).
