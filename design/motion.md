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

## Choreography

A transfer is a phase machine, and the transitions between phases are the product: `idle → starting → waiting / connecting → confirmSend | incoming → transferring → done | failed | stored`.

1. **The phase container cross-fades; its contents do not animate in separately.** One `--dur-base` `--ease-out` opacity transition on the block that swaps. No stagger, no cascade.
2. **What persists must not move.** The direction header, the trust badge and the code phrase keep their position across every phase that shows them. A code phrase that jumps when the transfer starts is the worst thing this screen can do, because it is what the user is reading aloud.
3. **Terminal phases arrive, they do not celebrate.** `done` and `failed` cross-fade in like any other phase. The StatusBlock glyph does not pop, spin or bounce, and there is no confetti (`brand.md` → Personality).

Progress fills animate width at `--dur-base` `--ease-out` and **never move backwards**. If a total revises downward, snap and keep moving forward.

The "taking longer than usual" hint fades in at `--dur-slow`, after the delay that triggers it, so it reads as information rather than alarm.

## Haptics and sound

**No sound, ever.** A file transfer that beeps in a meeting is a file transfer people turn off.

Haptics are iPhone only: iPad's are inconsistent across models and macOS has none. They are always additive: every event below is already visible and announced.

| Event | Feedback |
|---|---|
| transfer completed | `.success` |
| transfer failed, declined by the other device, or blocked | `.error` |
| incoming request arrives (the accept gate) | `.warning` |
| code phrase copied, code scanned | `.selection` |

Four events, and no more without a reason written down. Nothing fires on progress, phase changes inside a running transfer, button presses or navigation, so a Cancel or Decline the user tapped ends silently. The system haptic setting is respected; there is no switch of our own.
