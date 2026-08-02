# Accessibility

The binding floor for the app, the landing page and the docs site. Nothing in `components.md` is specced below it. Each section states the requirement; the reasoning lives in the topic file it points at.

## Contrast

WCAG 2.2 AA: body text ≥ 4.5:1, large text and UI component boundaries ≥ 3:1. **Light is the constrained theme** — check it first, dark clears everything.

Measured ratios and the seven rules that follow from them are in `colors.md` → Contrast. Two of them decide most component work:

- **Accent is a fill, not a label.** `#1E9E6A` is 3.41:1 on white — fine for fills, icons, borders and large text, never for a word. Accent text is `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and tinted surfaces.
- **A status color is a fill, never a foreground.** Status text is `--color-text-primary`; the tint and border carry the meaning.

Two deviations are documented and accepted at `colors.md` rule 3: filled prominent and destructive buttons ship at 3.41:1 and 3.55:1, on the condition that their label stays ≥ 17px semibold and small sizes use a tinted variant instead.

## Focus

Every interactive element takes `--shadow-focus-ring` on `:focus-visible`. Never remove focus styling without replacing it. A focus indicator owes 3:1 under SC 1.4.11 — it is not decoration, and it cannot be a tint. Mechanics in `materials-motion.md` → Focus.

## Hit targets

44×44pt minimum (`--hit-target-min`) for anything interactive, including bare icon buttons whose glyph is smaller than the target.

## Never color alone

Transfer direction is carried by the arrow glyph **and** the word "Sending" / "Receiving" — never by color or position (`components.md` → TransferProgress). Same for every status: the title states the outcome in words, the tint and glyph only repeat it.

## Icons and labels

Web glyphs are always `aria-hidden="true"`; the adjacent label carries the meaning. That is what makes a faint status glyph acceptable and what makes the label mandatory. App glyphs size by text style so they track Dynamic Type. See `iconography.md`.

## Dynamic Type

In the app use text styles, never a hardcoded point size, and verify at the largest accessibility size. The single literal size in the scale (`--type-code-hero`) still scales, through `@ScaledMetric`.

## Reduced motion

`prefers-reduced-motion` / `.accessibilityReduceMotion`: drop `--press-scale`, drop the indeterminate slide. Keep every state change — instant, not removed. See `materials-motion.md` → Motion.

## Reduced transparency

`prefers-reduced-transparency` / `.accessibilityReduceTransparency`: all three glass materials collapse to `solid`. `tokens.css` handles this at the token level, so a component consuming `--color-surface-glass` needs no branch of its own. See `materials-motion.md` → Reduced transparency.

## Nothing is hover-only

No hover-only buttons, no hover-only labels, no hover-to-reveal remove controls. Touch users have no pointer and keyboard users never trigger hover, so anything reachable only that way is unreachable for them. Hover may restate, never reveal. See `platforms.md` → Hover.

## Input is never drag-only

Every DropZone ships beside a real file-picker button. Drag-and-drop is unavailable to keyboard and to most assistive tech, so it can never be the only way to add files (`components.md` → DropZone).
