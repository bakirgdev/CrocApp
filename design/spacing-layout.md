# Spacing, radius, layout

4pt grid throughout. Every gap, pad and inset resolves to one of these steps.

## Spacing scale

| Token | Value |
|---|---|
| `--space-1` | 2px |
| `--space-2` | 4px |
| `--space-3` | 8px |
| `--space-4` | 12px |
| `--space-5` | 16px |
| `--space-6` | 20px |
| `--space-7` | 24px |
| `--space-8` | 32px |
| `--space-9` | 40px |
| `--space-10` | 48px |
| `--space-11` | 64px |

Common usage: screen padding `--space-5`, card padding `--space-6`, gap between unrelated blocks `--space-6` or `--space-7`, gap inside a row `--space-3` or `--space-4`. In SwiftUI a bare `.padding()` is the system default, not a token: write `.padding(Spacing.space5)`.

## Radii

iOS 26 continuous corners. **Concentric rule: outer radius = inner radius + the gap between them.** A 12px-padded card at `--radius-lg` (20) holds children at about 8: round down to `--radius-xs` or `--radius-sm` rather than inventing a value.

| Token | Value | Applies to |
|---|---|---|
| `--radius-xs` | 6px | inner chips, nested fills |
| `--radius-sm` | 10px | small tinted buttons, the paste button |
| `--radius-md` | 14px | fields, banners, list cards, QR frame |
| `--radius-lg` | 20px | cards, the drop zone |
| `--radius-xl` | 28px | the code phrase pill, large containers |
| `--radius-2xl` | 36px | the macOS drop overlay card |
| `--radius-capsule` | 999px | buttons, badges, progress bars |

On Apple platforms always use `style: .continuous` (`.rect(cornerRadius:style:)`, `RoundedRectangle(cornerRadius:style:)`). The circular style visibly mismatches system chrome.

## Layout cap

| Token | Value | Meaning |
|---|---|---|
| `--content-max-width` | 480px | the app's content column on every device; extra width becomes margin |

What legitimately differs per device is `platforms.md`.

## Control sizing

| Token | Value | Meaning |
|---|---|---|
| `--control-height-lg` | 50px | `.controlSize(.large)` buttons, the code field |
| `--control-height-md` | 38px | medium buttons |
| `--control-height-sm` | 30px | small buttons |
| `--hit-target-min` | 44px | HIG minimum target: the floor for anything interactive |
| `--icon-size-sm` | 17px | inline and row icons |
| `--icon-size-md` | 22px | default icon |
| `--icon-size-lg` | 28px | prominent icons |

Component constants (StatusBlock circle 64, TrustBadge full circle 34, QR frame 168, file row 48, drop zone 168) are specced in `components.md`. The app keeps the ones shared by more than one view in the `ComponentMetrics` enum and the rest private to their view; neither is a licence to invent a number at a call site.

## Web layout (landing and docs only)

`--content-max-width` is a phone-width column. A web page needs a page container, a prose measure, and rhythm that scales with the viewport. Both ends of every `clamp()` sit on the 4pt grid.

| Token | Value | Meaning |
|---|---|---|
| `--content-max-width-wide-web` | 1280px | hero, full-bleed rows, screenshot galleries |
| `--content-max-width-web` | 1080px | default section container |
| `--content-max-width-prose-web` | 680px | paragraph measure (about 75ch) |
| `--gutter-web` | `clamp(20px, 5vw, 48px)` | page horizontal padding |
| `--section-pad-web` | `clamp(64px, 9vw, 112px)` | vertical gap between sections |
| `--stack-web` | `clamp(32px, 4vw, 48px)` | gap between blocks inside a section |
| `--nav-height-web` | 56px | landing sticky nav; clears `--hit-target-min` with room either side |
| `--grid-min-card-web` | 232px | `auto-fit` column floor: 4-up at 1080, 2-up at 768, 1-up at 375. The largest grid value that fits four columns in `--content-max-width-web` (984 usable, minus 3 × 16 gap = 936, ÷ 4 = 234) |
| `--store-badge-height-web` | 40px | Apple's minimum onscreen badge height (`brand.md` → App Store badges) |
| `--step-marker-size-web` | 32px | numbered marker in a How it works list |
| `--mascot-size-web` | 64px | mascot in a footer or empty state |
| `--phone-shot-max-width-web` | 260px | a phone screenshot inline in docs prose. A portrait shot at 480 is over twice as tall as wide and pushes the prose off screen |

### Web component metrics

The same numbers `components.md` specifies, as tokens because web CSS may not hold a raw px.

| Token | Value | From |
|---|---|---|
| `--btn-pad-x-lg-web` / `-md-` / `-sm-` | 22px / 16px / 12px | Button size table |
| `--btn-gap-lg-web` / `-md-` / `-sm-` | 8px / 6px / 5px | Button size table |
| `--btn-icon-lg-web` / `-md-` / `-sm-` | 20px / 18px / 15px | Button size table, `iconography.md` |
| `--pill-pad-block-web` | 5px | TrustBadge pill |
| `--pill-pad-inline-start-web` / `-end-` | 9px / 11px | TrustBadge pill. Asymmetric: the glyph sits tighter to the leading edge |
| `--pill-icon-size-web` | 14px | TrustBadge pill |

### Breakpoints

Three, and no more without a reason written down. They are literals in the stylesheet because a custom property does not resolve inside a media condition, so this table is the only place they are defined. `rem`, so they follow the user's font size.

| Width | What changes |
|---|---|
| `30rem` | nav collapses the GitHub label to its glyph and count |
| `48rem` | nav keeps only its primary anchor |
| `64rem` | hero splits into copy and screenshot columns |

The docs theme (Docusaurus) collapses its navbar at its own breakpoint; that one is the theme's, not ours.

### Stacking order

Two layers. Anything that wants a third needs a reason first.

| Token | Value | Layer |
|---|---|---|
| `--z-nav-web` | 2 | sticky bar, above page content |
| `--z-skip-link-web` | 3 | above the bar it jumps past |

## Borders

| Token | Value |
|---|---|
| `--border-hairline` | 1px |
| `--border-hairline-half` | 0.5px |

Focus is a ring (`--shadow-focus-ring`, `materials.md` → Focus), never a border.

## Writing direction

Every spec names a leading and a trailing edge, never left and right. The CSS side is `web.md` → Writing direction; SwiftUI is leading/trailing by construction.
