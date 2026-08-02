# Motion and feedback

How the interface changes and how it answers back. What a surface is made of is `materials.md`.

## Motion

| Token | Value | Use |
|---|---|---|
| `--ease-standard` | `cubic-bezier(0.4, 0, 0.2, 1)` | color/background changes |
| `--ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | entrances, position, progress fills |
| `--dur-fast` | 120ms | press feedback, hover, focus |
| `--dur-base` | 220ms | segment thumb, toggle, progress |
| `--dur-slow` | 360ms | sheet / screen transitions |
| `--press-scale` | 0.97 | buttons shrink slightly when pressed |

Progress bars animate width at `--dur-base` `--ease-out`. The indeterminate bar is a 40%-wide fill sliding left `-40% → 100%` over 1.2s on `--ease-standard`, infinite.

Under `prefers-reduced-motion` / `.accessibilityReduceMotion`: drop `--press-scale`, drop the indeterminate slide (hold a static 40% fill or a pulsing opacity), keep every state change instant rather than removed. `tokens.css` zeroes the durations and the press scale; the looping animation is the component's own to gate.

## Choreography

A transfer is a phase machine, and the transitions between phases are the product. `idle → starting → waiting / connecting → confirmSend | incoming → transferring → done | failed`.

Three rules cover all of it:

1. **The phase container cross-fades; its contents do not animate in separately.** One `--dur-base` `--ease-out` opacity transition on the block that swaps. No stagger, no cascade, no springs. A transfer screen that performs is a transfer screen you do not trust.
2. **What persists must not move.** The direction header, the trust badge and the code phrase keep their position across every phase that shows them. Only the block below them changes. A code phrase that jumps when the transfer starts is the single worst thing this screen can do, because it is the thing the user is reading aloud.
3. **Terminal phases arrive, they do not celebrate.** `done` and `failed` cross-fade in at `--dur-base` like any other phase. The `StatusBlock` glyph does not pop, spin or bounce. There is no overshoot easing in this system, and `brand.md` already rules out confetti.

Progress fills animate width at `--dur-base` `--ease-out` and **never animate backwards**. If a total revises downward, snap the value and keep the bar moving forward.

Entering `waiting` is the one moment worth a beat: the code phrase appears with the container cross-fade, and nothing else on screen changes at the same time.

The "taking longer than usual" hint fades in at `--dur-slow`, well after the delay that triggers it, so it reads as information rather than as an alarm.

## Haptics and sound

**No sound, ever.** This app never plays audio. A file transfer that beeps in a meeting is a file transfer people turn off.

Haptics are iPhone only. iPad's are inconsistent across models and macOS has none, so haptics are always additive: every event below is already visible and already announced.

| Event | Feedback |
|---|---|
| transfer completed | `.success` |
| transfer failed, declined, or blocked | `.error` |
| incoming request arrives (the accept gate) | `.warning` |
| code phrase copied, code scanned | `.selection` |
| everything else | none |

Four events, and no more without a reason written down. Nothing fires on progress, on phase changes inside a running transfer, on button presses, or on navigation: the press scale is the button's feedback. Respect the system haptic setting rather than adding a switch of our own.
