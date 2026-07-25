# Token → SwiftUI mapping

How the web tokens translate to the app. Nothing here is implemented yet — this is the plan for the restyle session. **Verify every iOS 26 / macOS 26 API against current Apple docs (or the `xcode` MCP) before writing code**; the ones flagged *(verify)* are the newest and the most likely to have moved.

## Colors

Define one asset-catalog **Color Set per semantic alias**, with Any/Dark appearances filled from `colors.md`. Never reference a `--green-*` step from a view — views use the aliases only.

| Token | App |
|---|---|
| `--color-accent` | `AccentColor` color set (`#1E9E6A` / `#2DC585`); reach it via `.tint()` and `Color.accentColor` |
| `--color-accent-pressed` | color set; only needed for custom button styles |
| `--color-on-accent` | color set (`#FFFFFF` / `#05271A`) |
| `--color-text-primary/secondary/tertiary` | `.primary` / `.secondary` / `Color(.tertiaryLabel)` — prefer the system semantics over custom sets |
| `--color-status-success/warning/error/info` | `.green` / `.orange` / `.red` / `.blue` (system semantics already match the token values) |
| `--color-status-*-tint` | the status color at `.opacity(0.14)` light / `0.18` dark, or a color set |
| `--color-surface-grouped` | `Color(.systemGroupedBackground)` (iOS); on macOS use `.windowBackground` |
| `--color-surface-card` | `Color(.secondarySystemGroupedBackground)` (iOS); macOS `.background(.regularMaterial)` or a color set |
| `--color-separator` | `Color(.separator)` / the `Divider` default |
| `--color-scrim` | `.black.opacity(0.25 / 0.5)` |

`Color(.systemGroupedBackground)` and friends are UIKit-backed and iOS-only — cross-platform views need a color set or an `#if os()` split. That split already exists in the app; keep it in one place.

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
| `--radius-md/lg/xl` | `RoundedRectangle(cornerRadius:, style: .continuous)`, or `ConcentricRectangle` for nested corners *(verify — iOS 26 shape API)* |
| `--radius-capsule` | `Capsule()` / `.buttonBorderShape(.capsule)` |
| `--control-height-lg` | `.controlSize(.large)` |
| `--hit-target-min` | `.frame(minWidth: 44, minHeight: 44)` on bare icon buttons |
| `--content-max-width` | `.frame(maxWidth: 480)` on the content column |

Always `.continuous` corners. The default circular style visibly mismatches system chrome.

## Materials

`--color-surface-glass*` + `--blur-*` collapse to **`.glassEffect()`** *(verify signature and the `Glass` configuration type)*. Do not reproduce the CSS `backdrop-filter` recipe with `.ultraThinMaterial` plus a shadow — the CSS is the approximation, the native effect is the target.

Shadows: `--shadow-sm/md/lg` map to `.shadow(radius:y:)` with the same geometry, but prefer the material's own depth where one exists.

## Components

| Design system | SwiftUI |
|---|---|
| Button `prominent` | `.buttonStyle(.borderedProminent)` `.controlSize(.large)` `.buttonBorderShape(.capsule)`; iOS 26 `.glassProminent` where appropriate *(verify)* |
| Button `secondary` | `.buttonStyle(.bordered)` + `.tint(.accentColor)` |
| Button `destructive` | `.buttonStyle(.borderedProminent)` + `.tint(.red)`, or `Button(role: .destructive)` |
| Button `glass` | `.buttonStyle(.glass)` *(verify)* |
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

The restyle is cosmetic. It must not touch: the accept-gate flow (never auto-accept), the direction-unambiguous transfer screen, the prompt-pipe event handling, or the phase state machine. Read `docs/knowledge/app-ui-architecture.md` before editing any view that observes `TransferController`.
