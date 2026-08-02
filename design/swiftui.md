# Token → SwiftUI mapping

How the tokens translate to the app. The app side of this is live: `app/CrocApp/Support/DesignTokens.swift` holds the `Spacing`, `Radius`, `BorderWidth`, `ControlHeight`, `IconSize`, `LayoutCap`, `ComponentMetrics`, `Motion` and `Shadow` enums plus the `Color` aliases, and `app/CrocApp/Assets.xcassets` holds the color sets. Both are hand-synced mirrors of this directory — change a value here and change it there in the same commit.

The iOS 26 APIs below were checked against Apple's documentation on 2026-07-26; re-check anything that fails to compile rather than working around it, since these are new enough to still move.

## Colors

An asset-catalog **Color Set per semantic alias**, with Any/Dark appearances filled from `colors.md`. Where a system semantic already matches a token exactly, the alias routes to the system semantic instead of duplicating a color set. Never reference a `--green-*` step from a view — views use the aliases only.

| Token | App |
|---|---|
| `--color-accent` | `AccentColor` color set (`#1E9E6A` / `#2DC585`); reach it via `.tint()` and `Color.accentColor` |
| `--color-accent-pressed` | color set; only needed for custom button styles |
| `--color-accent-text` | color set (`#178055` / `#2DC585`) |
| `--color-accent-text-on-tint` | color set (`#116243` / `#2DC585`) |
| `--color-on-accent` | color set (`#FFFFFF` / `#05271A`) |
| `--color-on-status` | `.white` — the same in both themes, so it needs no color set |
| `--color-text-primary/secondary/tertiary` | `.primary` / `.secondary` / `Color(.tertiaryLabel)` — prefer the system semantics over custom sets |
| `--color-status-success/warning/error/info` | `.green` / `.orange` / `.red` / `.blue` (system semantics already match the token values) |
| `--color-status-*-tint` | the status color at `.opacity(0.14)` light / `0.18` dark, or a color set |
| `--color-surface-grouped` | `Color(.systemGroupedBackground)` (iOS); on macOS use `.windowBackground` |
| `--color-surface-card` | `Color(.secondarySystemGroupedBackground)` (iOS); macOS `.background(.regularMaterial)` or a color set |
| `--color-surface-base` | `Color(.systemBackground)` (iOS); macOS has no "base" surface distinct from the window background, so a bordered control's own fill takes `.textBackgroundColor` |
| `--color-separator` | `Color(.separator)` / the `Divider` default |
| `--color-scrim` | `.black.opacity(0.25 / 0.5)` |

`Color(.systemGroupedBackground)` and friends are UIKit-backed and iOS-only — cross-platform views need a color set or an `#if os()` split. `DesignTokens.swift` is the one file that carries that split; keep it there.

**`Color.accentColor` is a fill, not a label color.** `colors.md` rule 1 binds the app exactly as it binds the web: `.foregroundStyle(.tint)` on a word is 3.41:1 in the light theme and fails. Text that has to read as accent — a `.bordered` button's label, a plain-style action, a link — takes the `--color-accent-text` set, or `--color-accent-text-on-tint` on a grouped background or an accent tint. Both collapse to `#2DC585` in dark, so this only ever costs anything in light.

`.secondary` is `--label-2` (0.60), not the web alias `--label-2-web` (0.75). Deliberate — `colors.md` rule 4.

## Typography

The type scale **is** `Font.TextStyle`, so use the styles and inherit Dynamic Type for free:

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
| `--type-code-hero` | `.system(size: 30, weight: .bold, design: .monospaced)` — the one place a literal size is acceptable, and it must still scale (`@ScaledMetric`) |
| `--type-code-body` | `.body.monospaced()` |
| tabular figures | `.monospacedDigit()` |

Never set `.font(.system(size:))` for anything in the scale. Never bundle a font file.

## Spacing and shape

| Token | App |
|---|---|
| `--space-*` | a `Spacing` enum of `CGFloat` constants mirroring the 4pt scale |
| `--radius-md/lg/xl` | `RoundedRectangle(cornerRadius:, style: .continuous)`, or `ConcentricRectangle` for nested corners |
| `--radius-capsule` | `Capsule()` / `.buttonBorderShape(.capsule)` |
| `--control-height-lg` | `.controlSize(.large)` |
| `--hit-target-min` | `.frame(minWidth: 44, minHeight: 44)` on bare icon buttons |
| `--content-max-width` | `.frame(maxWidth: 480)` on the content column |

Always `.continuous` corners. The default circular style visibly mismatches system chrome.

`ConcentricRectangle` enforces the concentric rule from `spacing-layout.md` for free — corners resolve against the container instead of being computed by hand:

```swift
ConcentricRectangle(uniformTopCorners: .fixed(24.0), uniformBottomCorners: .concentric)
```

Corner styles are `.concentric`, `.concentric(minimum:)` and `.fixed(_:)`. A custom container has to declare `.containerShape(_:)` with a `RoundedRectangularShape` for the resolution to have anything to work from; without one the computed radius can collapse to zero, which is what `.concentric(minimum:)` guards against.

## Materials

`--color-surface-glass*` + `--blur-*` collapse to **`.glassEffect()`**:

```swift
func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View
```

`Glass` carries the variants (`.regular`, `.clear`). Multiple glass surfaces belong inside a **`GlassEffectContainer`** — it renders them as one shape set, which is both faster and what lets them morph into each other. Never hand-roll the CSS recipe with `.ultraThinMaterial` plus a shadow (`materials-motion.md` → Liquid Glass).

`.accessibilityReduceTransparency` falls back to `--color-surface-card`, not to a weaker blur (`materials-motion.md` → Reduced transparency).

Shadows: `--shadow-sm/md/lg` map to `.shadow(radius:y:)` with the same geometry, but prefer the material's own depth where one exists. `Shadow` in `DesignTokens.swift` currently carries only `md`; `sm`, `lg` and `knob` are still literal at their call sites, and `--shadow-focus-ring` has no Swift form at all (see below).

## Focus in the app

`--shadow-focus-ring` is a `box-shadow` construct and does **not** bind SwiftUI. On iOS a field's focus is its caret plus the accent border (`components.md` → CodeField); on macOS the system draws its own focus ring and overriding it is wrong. The app's obligation is the one in `accessibility.md`: a visible focus indicator that is never removed. The two-band ring is how the web meets that, not how the app does.

## What the app deliberately does not mirror

Not every token has a Swift counterpart, and the gaps are decisions, not drift:

| Token group | Why not |
|---|---|
| `--tracking-*` | text styles carry Apple's own optical tracking. Setting `.tracking()` on a system font fights the platform. The exception is `--tracking-eyebrow`, which is real letter-spacing on an uppercase label |
| `--icon-stroke-*` | SF Symbols have weights, not strokes. Size by text style, weight by `.symbolRenderingMode` |
| `--*-web`, `--btn-*`, `--pill-*`, `--nav-height-web`, `--grid-min-card`, `--z-*` | web-only by construction. `spacing-layout.md` says so |
| `--blur-*`, `--glass-*` | `.glassEffect()` owns these; there is nothing to set |

## States

| Token | App |
|---|---|
| `--opacity-disabled` 0.4 | the default `.disabled()` dimming; only override where SwiftUI does not dim for you |
| `--opacity-disabled-container` 0.5 | `.opacity()` on a row or field that dims as a whole |
| hover | `.onHover` on macOS and iPad-with-pointer; apply the pressed background, never a scale. Bare icon buttons may take `.hoverEffect()` |
| loading | keep the label and the frame, swap the leading glyph for `ProgressView()`, `.disabled(true)`. No skeletons |

## Haptics

`.sensoryFeedback(_:trigger:)`, iPhone only, four events, all additive to something already visible. The table is in `materials-motion.md` → Haptics and sound. The app plays no audio at all.

## Components

| Design system | SwiftUI |
|---|---|
| Button `prominent` | `.buttonStyle(.borderedProminent)` `.controlSize(.large)` `.buttonBorderShape(.capsule)`; `.glassProminent` where appropriate |
| Button `secondary` | `.buttonStyle(.bordered)` + `.tint(.accentColor)`; label takes `--color-accent-text-on-tint` |
| Button `destructive` | `.buttonStyle(.borderedProminent)` + `.tint(.red)`, or `Button(role: .destructive)` |
| Button `glass` | `.buttonStyle(.glass)` |
| DropZone | `.dropDestination(for:)` + a visible file-picker button beside it |
| Button `plain` | `.buttonStyle(.plain)` / `.borderless` |
| GlassCard | container + `.glassEffect()` + `.padding(20)` |
| SegmentedControl | `Picker` + `.pickerStyle(.segmented)` |
| CodeField | `TextField` + `.textFieldStyle(.plain)` inside a bordered container; `.monospaced()`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`; trailing `PasteButton` |
| SettingsRow | `List`/`Form` rows, `.listStyle(.insetGrouped)` on iOS, `Form` + `.formStyle(.grouped)` on macOS |
| Switch | `Toggle` (`.tint(.green)` to match the token) |
| FileRow | `List` row, `.truncationMode(.middle)` for the filename |
| ProgressBar | `ProgressView(value:total:)` `.progressViewStyle(.linear)`; indeterminate = `ProgressView()` |
| StatusBanner | custom view; `.accessibilityAddTraits(.isStaticText)` and an announcement for the error case |
| StatusBlock | custom centered view |
| EmptyState | `ContentUnavailableView` |
| SheetHeader | `.toolbar` with `ToolbarItem(placement: .cancellationAction / .confirmationAction)` |
| TrustBadge | custom capsule / row |

## Motion

| Token | App |
|---|---|
| `--dur-fast` 120ms | `.easeOut(duration: 0.12)` |
| `--dur-base` 220ms | `.easeOut(duration: 0.22)` or `.spring(duration: 0.22, bounce: 0.15)` |
| `--dur-slow` 360ms | system sheet/navigation transitions — do not override |
| `--press-scale` 0.97 | `.scaleEffect(isPressed ? 0.97 : 1)` inside a custom `ButtonStyle` |

Gate the press scale and any looping animation on `@Environment(\.accessibilityReduceMotion)`.

## Constraints carried from the app

Work driven by this directory is cosmetic. It must not touch: the accept-gate flow (never auto-accept), the direction-unambiguous transfer screen, the prompt-pipe event handling, or the phase state machine. Read `docs/knowledge/app-ui-architecture.md` before editing any view that observes `TransferController`.
