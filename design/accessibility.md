# Accessibility

The binding floor for the app, the landing page and the docs site. Nothing in `components.md` is specced below it. Each section states the requirement; the reasoning lives in the file it points at.

## Contrast

WCAG 2.2 AA: body text 4.5:1, large text and UI boundaries 3:1. **Light is the constrained theme:** check it first. Ratios and the seven rules are in `colors.md` → Contrast and are enforced by `scripts/verify-design.sh`. Two decide most work:

- **Accent is a fill, not a label.** Accent text is `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and tinted surfaces. In the app that includes every bordered and plain button label.
- **A status color is a fill, never a foreground.** Status text is `--color-text-primary`.

The one accepted deviation is the filled button (`colors.md` rule 3).

## Focus

Every interactive element shows a visible focus indicator that owes 3:1 (SC 1.4.11). Web: `--shadow-focus-ring` on `:focus-visible`, plus a transparent outline for forced-colors mode. App: the system indicator. Never remove one without replacing it (`materials.md` → Focus).

## Hit targets

44×44pt (`--hit-target-min`) for anything interactive, including small buttons, icon buttons and inline links in nav bars and footers.

## Never color alone

Direction is the arrow **and** the word "Sending" or "Receiving". Every status is stated in words; tint and glyph only repeat it. A glyph that is the only carrier of a status (HistoryRow) has an accessibility label.

## Icons and labels

Web glyphs are `aria-hidden="true"`; the adjacent label carries the meaning. App glyphs scale with Dynamic Type (`iconography.md` → Rendering).

## Dynamic Type

Text styles, never a fixed point size; glyph sizes through text styles or `@ScaledMetric`. Verify at the largest accessibility size: nothing clips, glyph frames take minimum widths.

## Reduced motion

No press scale, no indeterminate slide, every state change instant rather than removed (`motion.md` → Motion).

## Reduced transparency

Glass collapses to solid (`materials.md` → Reduced transparency).

## Nothing is hover-only

Touch and keyboard users never hover. Hover may restate, never reveal (`platforms.md` → Hover).

## Input is never drag-only

Every DropZone ships beside a real file-picker button.

## Announcements

Error banners and terminal failures are announced to VoiceOver; progress is not announced on every tick.
