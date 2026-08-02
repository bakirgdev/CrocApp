import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// This is the one file in the app that splits on `#if os()` for
// UIKit/AppKit-backed colors — see design/swiftui-mapping.md, "That split
// already exists in the app; keep it in one place."

/// 4pt spacing grid. design/spacing-layout.md → Spacing scale.
enum Spacing {
    static let space1: CGFloat = 2
    static let space2: CGFloat = 4
    static let space3: CGFloat = 8
    static let space4: CGFloat = 12
    static let space5: CGFloat = 16
    static let space6: CGFloat = 20
    static let space7: CGFloat = 24
    static let space8: CGFloat = 32
    static let space9: CGFloat = 40
    static let space10: CGFloat = 48
    static let space11: CGFloat = 64
}

/// Concentric radii. design/spacing-layout.md → Radii. Always pair with
/// `style: .continuous` — "the default circular style visibly mismatches
/// system chrome" (swiftui-mapping.md).
enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
    static let capsule: CGFloat = 999
}

/// design/spacing-layout.md → Borders.
enum BorderWidth {
    static let hairline: CGFloat = 1
    static let hairlineHalf: CGFloat = 0.5
}

/// design/spacing-layout.md → Control sizing.
enum ControlHeight {
    static let large: CGFloat = 50
    static let medium: CGFloat = 38
    static let small: CGFloat = 30
    /// HIG floor for anything interactive, not a control size proper.
    static let hitTargetMin: CGFloat = 44
}

/// design/spacing-layout.md → Control sizing.
enum IconSize {
    static let small: CGFloat = 17
    static let medium: CGFloat = 22
    static let large: CGFloat = 28
}

/// design/spacing-layout.md → Layout caps.
enum LayoutCap {
    static let contentMaxWidth: CGFloat = 480
    static let sheetMaxWidth: CGFloat = 540
}

/// Constants shared by more than one component. design/spacing-layout.md →
/// "Row heights that are not tokenized (they are component constants, see
/// components.md)". Anything used by only one component stays a private
/// constant inside that component's file instead (components.md's own rule).
enum ComponentMetrics {
    static let settingsRowMinHeight: CGFloat = 52
    static let fileRowMinHeight: CGFloat = 48
    static let sheetHeaderMinHeight: CGFloat = 52
    static let switchSize = CGSize(width: 51, height: 31)
    static let settingsRowIconTile: CGFloat = 29
    static let settingsRowIconTileRadius: CGFloat = 7
    static let statusBlockCircle: CGFloat = 64
    static let statusBlockGlyph: CGFloat = 34
    static let trustBadgeFullCircle: CGFloat = 34
    static let qrFrameDefault: CGFloat = 168
}

/// design/motion.md → Motion. Durations in seconds for `Animation`.
enum Motion {
    static let durationFast: Double = 0.12
    static let durationBase: Double = 0.22
    static let durationSlow: Double = 0.36
    static let pressScale: CGFloat = 0.97
}

/// design/materials.md → Elevation. Geometry is theme-independent
/// (materials.md's own words); only the shadow alpha flips per
/// appearance, which is why the applied form lives behind a view modifier
/// below instead of sitting here as plain constants like `Motion`.
enum Shadow {
    /// `--shadow-md` outer layer: `0 4px 16px`.
    static let mdOuterRadius: CGFloat = 16
    static let mdOuterY: CGFloat = 4
    /// `--shadow-md` inner layer: `0 1px 3px`.
    static let mdInnerRadius: CGFloat = 3
    static let mdInnerY: CGFloat = 1
    static let mdAlphaLight: (outer: Double, inner: Double) = (0.08, 0.05)
    static let mdAlphaDark: (outer: Double, inner: Double) = (0.50, 0.40)
}

/// SwiftUI's `.shadow()` is single-layer where `--shadow-md` is two CSS
/// layers, so this stacks two `.shadow()` calls to reproduce both rather
/// than collapsing to a one-layer approximation.
private struct ShadowMdModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let alpha = colorScheme == .dark ? Shadow.mdAlphaDark : Shadow.mdAlphaLight
        content
            .shadow(
                color: .black.opacity(alpha.outer), radius: Shadow.mdOuterRadius, x: 0,
                y: Shadow.mdOuterY
            )
            .shadow(
                color: .black.opacity(alpha.inner), radius: Shadow.mdInnerRadius, x: 0,
                y: Shadow.mdInnerY
            )
    }
}

extension View {
    /// design/materials.md → Elevation, `--shadow-md`.
    func shadowMd() -> some View {
        modifier(ShadowMdModifier())
    }
}

extension Color {
    // MARK: - Accent (design/colors.md → Semantic aliases; design/swiftui-mapping.md → Colors)

    /// Accent as a fill/icon/border/progress color — routes to the
    /// `AccentColor` asset set so `.tint()` / `Color.accentColor` pick it up
    /// for free. "`Color.accentColor` is a fill, not a label color."
    /// (swiftui-mapping.md) — never use this for a word, see `accentText`.
    static var accentFill: Color { .accentColor }

    /// Pressed state for custom button styles built on the accent fill.
    static let accentPressed = Color("ColorAccentPressed")

    /// Accent as *text*. Accent-as-text is a different value from
    /// accent-as-fill: the brand green is 3.41:1 on white as a fill, which
    /// clears the 3:1 UI floor but not the 4.5:1 body-text floor, so text
    /// takes the darker `--green-700` step in light (colors.md rule 1). Both
    /// collapse to the same value in dark.
    static let accentText = Color("ColorAccentText")

    /// Accent text on a tinted or grouped surface — one step darker again
    /// (`--green-800`) because `accentText` only clears AA on base/card.
    static let accentTextOnTint = Color("ColorAccentTextOnTint")

    /// Label drawn on top of a solid accent fill (e.g. a prominent button).
    static let onAccent = Color("ColorOnAccent")

    // MARK: - Text (design/swiftui-mapping.md → Colors)

    /// "prefer the system semantics over custom sets" for text
    /// primary/secondary/tertiary.
    static var textPrimary: Color { .primary }

    /// "`.secondary` is `--label-2` (0.60), not the web alias — that is
    /// deliberate. The app stays visually native; only the web needs the
    /// 0.75 correction." (swiftui-mapping.md, see colors.md rule 4.)
    static var textSecondary: Color { .secondary }

    /// Tertiary is decorative-only, never text: "`--color-text-tertiary` is
    /// not a text color and not a UI-boundary color. 1.74:1. Decorative
    /// fills only." (colors.md rule 5.)
    static var textTertiary: Color {
        #if os(iOS)
        Color(uiColor: .tertiaryLabel)
        #else
        Color(nsColor: .tertiaryLabelColor)
        #endif
    }

    // MARK: - Status (design/swiftui-mapping.md → Colors)

    /// "system semantics already match the token values" for the four
    /// status colors. A status color is a fill/glyph only, never a
    /// foreground for text (colors.md rule 2) — see the `*Tint` colors below
    /// for banner/badge backgrounds, and `Color.textPrimary` for their labels.
    static var statusSuccess: Color { .green }
    static var statusWarning: Color { .orange }
    static var statusError: Color { .red }
    static var statusInfo: Color { .blue }

    /// The four tints bake their alpha into the asset (14% light / 18%
    /// dark) rather than `.opacity()`, because the alpha itself differs by
    /// appearance — `.opacity()` can only apply one number to both.
    static let statusSuccessTint = Color("ColorStatusSuccessTint")
    static let statusWarningTint = Color("ColorStatusWarningTint")
    static let statusErrorTint = Color("ColorStatusErrorTint")
    static let statusInfoTint = Color("ColorStatusInfoTint")

    // MARK: - Surfaces (design/swiftui-mapping.md → Colors)

    /// "`Color(.systemGroupedBackground)` (iOS); on macOS use `.windowBackground`".
    static var surfaceGrouped: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// `--color-surface-base` (colors.md → Semantic aliases): the plain,
    /// unelevated page fill beneath grouped/card surfaces. Not in
    /// swiftui-mapping.md's Colors table (a gap in that doc); iOS takes the
    /// literal match, `.systemBackground`. macOS has no equivalent "base"
    /// surface distinct from the window background, so this takes the
    /// closest system semantic for a bordered control's own fill —
    /// `.textBackgroundColor` — which is what CodeField (today's only
    /// consumer) needs it for.
    static var surfaceBase: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }

    /// "`Color(.secondarySystemGroupedBackground)` (iOS); macOS
    /// `.background(.regularMaterial)` or a color set" — this file exposes a
    /// plain `Color`, not a material, so macOS takes the closest solid
    /// analog (`controlBackgroundColor`, content resting above the window
    /// background); a view that wants the actual glass card uses
    /// `.background(.regularMaterial)` directly instead of this token.
    static var surfaceCard: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// "`Color(.separator)` / the `Divider` default".
    static var separatorToken: Color {
        #if os(iOS)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    /// `--paper` (colors.md): the literal white/black ink color, not a
    /// themed surface. Used directly where a component knocks a glyph out
    /// of a solid fill (e.g. TrustBadge `full`), never as a page background.
    static let paper = Color("ColorPaper")

    /// design/colors.md → Semantic aliases: `--color-scrim`.
    static let scrim = Color("ColorScrim")
}

/// The sender's code-phrase display: the one documented literal font size
/// in the type scale (design/swiftui-mapping.md → Typography, "the one
/// place a literal size is acceptable, and it must still scale"). Wrapped in
/// `@ScaledMetric` so it keeps tracking Dynamic Type despite the literal.
private struct CodeHeroTextStyle: ViewModifier {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .monospaced))
    }
}

extension View {
    /// design/typography.md → Mono display sizes, `--type-code-hero` 30/38.
    func codeHeroTextStyle() -> some View {
        modifier(CodeHeroTextStyle())
    }
}
