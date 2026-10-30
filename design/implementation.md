# Implementation

How the tokens reach each surface. `tokens.css` is canonical for values; this file maps a token to a SwiftUI API or to web CSS and never redefines one. The app's mirrors are `app/CrocApp/Support/DesignTokens.swift` (constants and `Color` aliases) and the color sets in `app/CrocApp/Assets.xcassets`; `scripts/verify-design.sh` checks both against `tokens.css`. The SwiftUI APIs named here were checked against the iOS 26 SDK; if one fails to compile, re-check Apple's documentation rather than working around it.

## Colors

Views use the `Color` aliases in `DesignTokens.swift`, never a color set name, an `--olive-*` step or a raw `.green`, `.red`, `.orange` or `.blue`. One color set exists per alias with no exact system equivalent; the rest route to system semantics.

| Token | App |
|---|---|
| `--color-accent` | `AccentColor` set, `Color.accentFill` (also the global tint) |
| `--color-accent-solid` | `ColorAccentSolid`, `Color.accentSolid` (the prominent button tint and any solid accent fill that carries a label) |
| `--color-accent-pressed` | `ColorAccentPressed`, `Color.accentPressed` |
| `--color-accent-tint` | `ColorAccentTint`, `Color.accentTint` |
| `--color-accent-text`, `--color-text-link` | `ColorAccentText`, `Color.accentText` |
| `--color-accent-text-on-tint` | `ColorAccentTextOnTint`, `Color.accentTextOnTint` (optional, the stronger step) |
| `--color-on-accent` | `ColorOnAccent`, `Color.onAccent` |
| `--color-on-status` | `Color.onStatus` (`.white` in both themes) |
| `--color-text-primary` | `.primary`, via `Color.textPrimary` |
| `--color-text-secondary` | `ColorTextSecondary`, `Color.textSecondary`: the only secondary text color |
| `--color-text-tertiary` | no alias: decorative only, so a glyph that needs it takes the system `.tertiary` style |
| `--color-status-success`, `-warning`, `-error`, `-info` | `Color.statusSuccess` and so on (the system colors match the tokens) |
| `--color-status-*-tint` | `ColorStatus*Tint`, `Color.status*Tint` |
| `--color-surface-grouped` | no alias: the system supplies it through grouped containers such as `Form` |
| `--color-surface-card`, `--color-surface-base`, `--color-separator` | `Color.surfaceCard`, `.surfaceBase`, `.separatorToken` |
| `--color-scrim`, `--paper` | `ColorScrim` and `ColorPaper` sets, `Color.scrim`, `Color.paper` (a glyph knocked out of a solid fill) |

UIKit and AppKit colors need an `#if os()` split, which `DesignTokens.swift` alone carries. `AccentColor` is the global tint, so a bordered or plain button label inherits it at 4.06:1 unless the variant sets the label, which is why buttons go through `ButtonVariants.swift`. Text takes `Color.textSecondary`, including a footer or an EmptyState description inside a system control; `.secondary` is for glyphs and large text (`principles.md`, "Contrast").

## Typography

The scale is `Font.TextStyle`: `--type-large-title` is `.largeTitle`, `--type-title1` to `3` are `.title`, `.title2`, `.title3`, `--type-headline` is `.headline`, `--type-body` is `.body`, `--type-callout` is `.callout`, `--type-subhead` is `.subheadline`, `--type-footnote` is `.footnote`, and `--type-caption1` and `2` are `.caption` and `.caption2`. The code hero is `.codeHeroTextStyle()` (30pt bold mono through `@ScaledMetric`), code body is `.subheadline.monospaced()`, tracking is `.tracking(Tracking.code)` or `Tracking.eyebrow`, and tabular figures are `.monospacedDigit()`. Never `.font(.system(size:))` for text, and never bundle a font.

## Spacing, shape, layout

`--space-*` is `Spacing.space1` to `space11`; `--radius-*` is `Radius.xs` to `Radius.xxl` (always `style: .continuous`) and `--radius-capsule` is `Capsule()` or `.buttonBorderShape(.capsule)`; `--border-hairline` is `BorderWidth.hairline`; `--control-height-*` and `--hit-target-min` are `ControlHeight.*` (large buttons take `.controlSize(.large)`); `--icon-size-*` is `IconSize.*`; `--content-max-width` is `LayoutCap.contentMaxWidth`; `--opacity-disabled-container` is `Opacity.disabledContainer`. A component constant used by two views goes in `ComponentMetrics`, otherwise private to its view.

Navigation: the root reads `@Environment(\.horizontalSizeClass)` (compact is Home in a `NavigationStack`, regular is a two-column `NavigationSplitView`) and the Mac sidebar asks for `navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)`. Wiring, the cap and `AppRouter`: `docs/knowledge/app-ui-architecture.md`, "Layout by width".

## Materials, motion and haptics

- **Glass** is `.glassEffect(_:in:)`, with sibling surfaces in a `GlassEffectContainer`. The system handles reduced transparency. Drawn surfaces take a shadow through `.shadowMd()`.
- **Motion tokens:** `--dur-fast`, `-base`, `-slow` are `Motion.durationFast/Base/Slow`; `--ease-out` and `--ease-standard` are `Motion.easeOut(_:)` and `Motion.easeStandard(_:)` timing curves. The app also uses the system's own animations and springs where the system supplies them.
- Phase changes animate on `phaseKind` with `.transition(.opacity)` on the swapping container. Read `@Environment(\.accessibilityReduceMotion)` and pass `nil`, or `.contentTransition(.identity)`, when it is on.
- Symbol replace is `.contentTransition(.symbolEffect(.replace))`, numeric text is `.contentTransition(.numericText())` with `.monospacedDigit()`, and the waiting pulse is `.symbolEffect(.pulse, isActive:)`.
- **Haptics** are `.sensoryFeedback(_:trigger:)`, only on iPhone and only while the Haptics setting is on. No audio.
- **Focus** is the system's in the app. `--shadow-focus-ring` is a web construct.

## Components

| Design | SwiftUI |
|---|---|
| Button `prominent` | `.buttonStyle(.borderedProminent)`, `.buttonBorderShape(.capsule)`, tint `Color.accentSolid`, label `Color.onAccent` |
| Button `secondary` | `.buttonStyle(.bordered)`, tint `Color.accentFill`, label `Color.accentTextOnTint` |
| Button `destructive` | `.buttonStyle(.borderedProminent)`, tint `Color.statusError`, label `Color.onStatus` |
| Button `destructive-tinted` | `.buttonStyle(.bordered)`, tint `Color.statusError`, label `Color.textPrimary` |
| Button `plain` | `.buttonStyle(.borderless)`, label `Color.accentTextOnTint` |

The variants are one modifier, `.buttonVariant(_:)`, in `ButtonVariants.swift`, and the label color is set on the label content so the system style cannot override it. A `role: .destructive` button always takes `destructive` or `destructive-tinted`.

## Icons

SF Symbols in the app, [Lucide](https://lucide.dev) (ISC) on the web, the closest rounded-outline match. A glyph that carries a shared meaning keeps the pair below.

| Meaning | Lucide (web) | SF Symbol (app) |
|---|---|---|
| Send, Receive | `circle-arrow-up`, `circle-arrow-down` | `arrow.up.circle`, `arrow.down.circle` (`.fill` on the Home buttons) |
| Sending, Receiving (direction header) | `arrow-up`, `arrow-down` | `arrow.up`, `arrow.down` |
| Folder, file, text, image | `folder`, `file`, `file-text`, `image` | `folder`, `doc`, `doc.text`, `photo` |
| Success, confirm, copied | `circle-check`, `check` | `checkmark.circle`, `checkmark` |
| Copy | `copy` | `doc.on.doc` |
| Encrypted (pill), verified (full badge) | `lock`, `shield-check` | `lock.fill`, `checkmark.shield.fill` |
| Local network | `wifi` | `wifi` |
| Warning, error, info | `triangle-alert`, `circle-alert`, `info` | `exclamationmark.triangle.fill`, `exclamationmark.circle.fill`, `info.circle` |
| Disclosure | `chevron-right` | `chevron.right` |
| Share, drop zone | `share`, `upload` | `square.and.arrow.up` |
| Settings | `settings` | `gearshape` |

Check an SF Symbol name in the SF Symbols app before first use. Lucide names were checked against lucide-static 1.59.0.

- **App:** size by text style (`.font(.headline)`, `.imageScale`) or `@ScaledMetric` where a component needs a point size. `.symbolRenderingMode(.hierarchical)` in tinted tiles, monochrome inline, `.fill` variants inside colored circles. Tint through the color aliases.
- **Web:** one inline `<symbol>` sprite referenced with `<use>`, 24×24 viewBox, `fill: none`, `stroke: currentColor`, round caps, always `aria-hidden="true"`. The sprite comment names the Lucide version. No brand icons (Lucide 1.x removed them, so the GitHub link is `star` plus the word "GitHub"). Use canonical `circle-*` names, not the legacy `*-circle` spellings: `check-circle` is a different glyph. Stroke widths are the unitless `--icon-stroke-*` tokens, because `stroke-width` scales with the viewBox.

## Not mirrored

These shared tokens have no Swift form on purpose. `scripts/verify-design.sh` skips them and everything with a `web` name segment.

| Tokens | Why |
|---|---|
| `--olive-*`, `--khaki-*`, `--sys-*`, `--label-*`, `--fill-*`, `--bg-*`, `--separator*` | base palette: views take aliases, which route to system semantics or color sets |
| `--glass-*`, `--blur-*`, `--color-surface-glass*`, `--color-glass-border`, `--shadow-glass` | `.glassEffect()` owns them |
| `--shadow-sm`, `--shadow-lg`, `--shadow-focus-ring` | system controls carry their own depth and focus |
| `--type-*`, `--weight-*`, `--font-*`, and `--tracking-*` except code and eyebrow | `Font.TextStyle` is the scale and carries Apple's tracking |
| `--icon-stroke-*` | SF Symbols have weights, not strokes |
| `--color-text-primary/tertiary/quaternary/link`, `--color-fill*`, `--color-surface-*`, `--color-separator`, `--color-status-*` (not the tints), `--color-on-status` | values come from the OS (or `.white`), so there is no number to compare |

## Web

Applies to the landing page (`web/landing`) and the docs site (`web/docs`), which consume `tokens.css` and never a copy (`design/AGENTS.md`, "Mirrors and checks"). Both ship both themes and follow the OS.

- **Page fill** is `--color-surface-base`, set on `body`. Cards are `--color-surface-card` with a hairline border, because in light the two fills are the same white.
- **Theming.** Every themed token is a `light-dark()` pair resolved by `color-scheme`; `:root` declares `light dark` and `[data-theme="light"]` or `"dark"` pins it. The landing sets `data-theme` from `localStorage` in the synchronous `theme-init.js` before first paint, and the toggle rewrites `<meta name="theme-color">`.
- **Width and type.** Caps and fluid rhythm come from the `--content-max-width-*-web` and `--section-pad-web` tokens; headings take the `.t-web-*` classes, everything at body size and below the shared scale. An element that depicts the app (a hero screenshot) takes `--content-max-width`.
- **Glass.** Only the sticky nav is glass; everything else is solid.
- **Hover and focus.** Hover is the pressed background inside `@media (hover: hover)`. Focus is `--shadow-focus-ring`, never restyled per component.
- **Head, images and policy** (CSP, favicon links, Open Graph, crawler files): `docs/knowledge/landing-page.md`.

### Docs site

`web/docs/src/css/custom.css` maps Infima's variables onto tokens: the primary ladder onto the accent aliases (a `.button--primary` takes `--color-accent-solid` so its label clears AA), links on a fill wash onto `--color-accent-text`, grays onto fills and separators, admonitions onto the status tints (text stays primary), headings onto the web scale, and the code theme onto tokens. `web/docs/src/prismTheme.ts` writes `var(--token)` strings. The mascot is the navbar mark.

### Raw colors on web

Web code writes color tokens, not literals. `scripts/verify-design.sh` flags a hex color, an `rgb()`, `hsl()` or similar function, or a named color (`white`, `red`) in the web CSS, in the landing HTML, and in `app.js`, `theme-init.js`, `receive.js` and `prismTheme.ts`. The exceptions are `transparent`, `currentColor`, `black` inside `color-mix()` (the pressed state of a filled destructive button), the two `theme-color` meta values, and `theme_color` and `background_color` in `site.webmanifest`, which browser chrome cannot take from a custom property. The manifest values must equal `--bg-base` in light, which the script checks.
