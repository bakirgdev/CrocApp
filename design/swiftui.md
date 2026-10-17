# Token to SwiftUI

How the tokens reach the app. `app/CrocApp/Support/DesignTokens.swift` holds the constants and color aliases; `app/CrocApp/Assets.xcassets` holds the color sets. `scripts/verify-design.sh` checks both against `tokens.css`.

The iOS 26 APIs here were checked against Apple's documentation on 2026-07-26. If one fails to compile, re-check the docs rather than working around it.

## Colors

One color set per semantic alias that has no exact system equivalent; a system semantic otherwise. Views use the `Color` aliases in `DesignTokens.swift`, never a color set name, a `--green-*` step or a raw `.green`/`.red`/`.orange`/`.blue`.

| Token | App |
|---|---|
| `--color-accent` | `AccentColor` set; `Color.accentFill` (also the global tint) |
| `--color-accent-pressed` | `ColorAccentPressed` set; `Color.accentPressed` |
| `--color-accent-tint` | `ColorAccentTint` set; `Color.accentTint` |
| `--color-accent-text`, `--color-text-link` | `ColorAccentText` set; `Color.accentText` |
| `--color-accent-text-on-tint` | `ColorAccentTextOnTint` set; `Color.accentTextOnTint` |
| `--color-on-accent` | `ColorOnAccent` set; `Color.onAccent` |
| `--color-on-status` | `Color.onStatus` (`.white` in both themes) |
| `--color-text-primary/secondary/tertiary` | `.primary` / `.secondary` / tertiary label, via `Color.textPrimary/Secondary/Tertiary` |
| `--color-status-success/warning/error/info` | `Color.statusSuccess/Warning/Error/Info` (system green, orange, red, blue match the tokens) |
| `--color-status-*-tint` | `ColorStatus*Tint` sets; `Color.status*Tint` |
| `--color-surface-grouped` | `Color.surfaceGrouped` (iOS grouped background, macOS window background) |
| `--color-surface-card` | `Color.surfaceCard` |
| `--color-surface-base` | `Color.surfaceBase` |
| `--color-separator` | `Color.separatorToken` |
| `--color-scrim` | `ColorScrim` set; `Color.scrim` |
| `--paper` | `ColorPaper` set; `Color.paper` (a glyph knocked out of a solid fill) |

UIKit/AppKit-backed colors need an `#if os()` split; `DesignTokens.swift` is the one file that carries it.

**`Color.accentFill` is a fill, not a label color** (`colors.md` rule 1). `AccentColor` is the global tint, so every `.bordered`, `.borderless` and plain button label inherits it at 3.41:1 unless the button variant sets the label. That is why buttons go through the variants below and never style themselves.

`.secondary` is `--label-2` (0.60), not the web's `--label-2-web` (0.75): deliberate, `colors.md` rule 4.

## Typography

The type scale is `Font.TextStyle`:

| Token | App |
|---|---|
| `--type-large-title` | `.largeTitle` |
| `--type-title1/2/3` | `.title` / `.title2` / `.title3` |
| `--type-headline` | `.headline` |
| `--type-body` | `.body` |
| `--type-callout` | `.callout` |
| `--type-subhead` | `.subheadline` |
| `--type-footnote` | `.footnote` |
| `--type-caption1/2` | `.caption` / `.caption2` |
| `--type-code-hero` | `.codeHeroTextStyle()`: 30pt bold monospaced through `@ScaledMetric` |
| `--type-code-body` | `.subheadline.monospaced()` |
| `--tracking-code`, `--tracking-eyebrow` | `.tracking(Tracking.code)`, `.tracking(Tracking.eyebrow)` |
| tabular figures | `.monospacedDigit()` |

Never a fixed `.font(.system(size:))`: text takes a style, and a glyph size a component specifies goes through `@ScaledMetric`. Never bundle a font.

## Spacing, shape, layout

| Token | App |
|---|---|
| `--space-*` | `Spacing.space1` … `Spacing.space11` |
| `--radius-*` | `Radius.xs` … `Radius.xxl` (`--radius-2xl`), always `style: .continuous` |
| `--radius-capsule` | `Capsule()`, `.buttonBorderShape(.capsule)` |
| `--border-hairline(-half)` | `BorderWidth.hairline`, `.hairlineHalf` |
| `--control-height-*`, `--hit-target-min` | `ControlHeight.large/medium/small`, `.hitTargetMin`; large buttons take `.controlSize(.large)` |
| `--icon-size-*` | `IconSize.small/medium/large` |
| `--content-max-width` | `LayoutCap.contentMaxWidth` |
| `--opacity-disabled-container` | `Opacity.disabledContainer` |
| component constants | `ComponentMetrics` when shared by two views, otherwise a private constant in the view |

## Materials

Glass is `.glassEffect(_:in:)`; several glass surfaces share a `GlassEffectContainer` so they render and morph as one. `.accessibilityReduceTransparency` is handled by the system effect. Shadows: only drawn surfaces take one, through `.shadowMd()` (`materials.md` → Elevation).

## Focus

The system draws focus on both platforms. `--shadow-focus-ring` is a web construct. A field's focus is its caret plus the accent border (`components.md` → CodeField).

## Motion

| Token | App |
|---|---|
| `--dur-fast/base/slow` | `Motion.durationFast/Base/Slow` |
| `--ease-out` | `Motion.easeOut(_:)` = `.timingCurve(0.16, 1, 0.3, 1, duration:)` |
| `--ease-standard` | `Motion.easeStandard(_:)` = `.timingCurve(0.4, 0, 0.2, 1, duration:)` |

Phase changes animate with `Motion.easeOut(Motion.durationBase)` on the swapping container and `.transition(.opacity)`. Read `@Environment(\.accessibilityReduceMotion)` and pass `nil` when it is on. No `.spring`, no `.bouncy`, no `.snappy` (`motion.md`).

Haptics: `.sensoryFeedback(_:trigger:)`, iPhone only (`UIDevice.current.userInterfaceIdiom == .phone`), the four events in `motion.md` → Haptics and sound. No audio.

## Components

| Design | SwiftUI |
|---|---|
| Button `prominent` | `.buttonStyle(.borderedProminent)`, `.buttonBorderShape(.capsule)`, label `Color.onAccent` |
| Button `secondary` | `.buttonStyle(.bordered)`, tint `Color.accentFill`, label `Color.accentTextOnTint` |
| Button `destructive` | `.buttonStyle(.borderedProminent)`, tint `Color.statusError`, label `Color.onStatus` |
| Button `destructive-tinted` | `.buttonStyle(.bordered)`, tint `Color.statusError`, label `Color.textPrimary` |
| Button `plain` | `.buttonStyle(.borderless)`, label `Color.accentTextOnTint`, which clears AA on every app surface (grouped page and cards alike) |

The variants live in `app/CrocApp/Views/ButtonVariants.swift` as one `View` modifier (`.buttonVariant(.prominent)`), and the label color is set on the label content so the system style cannot override it. Large primary actions add `.controlSize(.large)`. A `role: .destructive` button always takes `destructive` or `destructive-tinted`.

Everything else is mapped in `components.md`: drawn components name their measurements, system controls name their API.

## Allowed literals

`DesignTokens.swift`, the color sets, and these, each next to the spec it comes from:

- component constants named in `components.md` (12 QR padding, 22% banner border, 168 drop zone), as private `let`s or `ComponentMetrics`;
- `Color.white` for the QR frame, which is white in both themes;
- window sizes from `platforms.md` in the scene declarations.

## Not mirrored

These tokens have no Swift form on purpose. `scripts/verify-design.sh` skips them and everything with a `web` name segment:

| Tokens | Why |
|---|---|
| `--green-*`, `--sys-*`, `--label-*`, `--fill-*`, `--bg-*`, `--separator*` | base palette: views take aliases, which route to system semantics or color sets |
| `--glass-*`, `--blur-*`, `--color-surface-glass*`, `--color-glass-border`, `--shadow-glass` | `.glassEffect()` owns them |
| `--shadow-sm`, `--shadow-lg`, `--shadow-focus-ring` | system controls carry their own depth and focus |
| `--type-*` sizes, line-heights and weights, `--weight-*`, `--font-*` | `Font.TextStyle` is the scale |
| `--tracking-*` except code and eyebrow | text styles carry Apple's optical tracking; `.tracking()` on a system style fights it |
| `--icon-stroke-*` | SF Symbols have weights, not strokes |
| `--color-text-quaternary`, `--color-fill*` | system semantics, used through the system controls |
| `--color-text-primary/secondary/tertiary`, `--color-text-link`, `--color-surface-*`, `--color-separator`, `--color-status-*` (not the tints), `--color-on-status` | mirrored by name as `Color` aliases above, but their values come from the OS (or `.white`), so there is no number to compare |

## Constraints carried from the app

Design work here is cosmetic. It must not change what the transfer does: the accept gate never auto-accepts unless the user turned it on, direction stays unambiguous, and the prompt-pipe handling and phase machine stay as they are. Read `docs/knowledge/app-ui-architecture.md` before editing any view that observes `TransferController`.
