import SwiftUI

/// 4pt spacing grid.
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

/// Concentric radii. Always pair with `style: .continuous`.
enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
    static let capsule: CGFloat = 999
}

/// design/principles.md → Spacing and layout.
enum BorderWidth {
    static let hairline: CGFloat = 1
    static let hairlineHalf: CGFloat = 0.5
}

/// design/principles.md → Spacing and layout.
enum ControlHeight {
    static let large: CGFloat = 50
    static let medium: CGFloat = 38
    static let small: CGFloat = 30
    /// HIG floor for anything interactive, not a control size proper.
    static let hitTargetMin: CGFloat = 44
}

/// design/principles.md → Spacing and layout.
enum IconSize {
    static let small: CGFloat = 17
    static let medium: CGFloat = 22
    static let large: CGFloat = 28
}

/// design/principles.md → Spacing and layout.
enum LayoutCap {
    static let contentMaxWidth: CGFloat = 480
}

/// design/components.md → States: `--opacity-disabled-container`.
enum Opacity {
    static let disabledContainer: Double = 0.5
}

/// design/principles.md → Type: `--tracking-code`, `--tracking-eyebrow`.
enum Tracking {
    static let code: CGFloat = 0.5
    static let eyebrow: CGFloat = 0.6
}

/// Constants shared by more than one component. Anything used by only one component stays a private
/// constant inside that component's file instead.
enum ComponentMetrics {
    static let fileRowMinHeight: CGFloat = 48
    static let statusBlockCircle: CGFloat = 64
    static let statusBlockGlyph: CGFloat = 34
    static let trustBadgeFullCircle: CGFloat = 34
    static let qrFrameDefault: CGFloat = 168
    /// Status border alpha for StatusBanner and TrustBadge `full`
    /// (components.md → StatusBanner: 22% of the kind color).
    static let statusBorderOpacity: Double = 0.22
    /// Fill alpha of a system color used as a tint (banners, badges, status glyph
    /// circles, the drag-over drop zone).
    static let tintOpacity: Double = 0.14
}

/// design/principles.md → Motion. Durations in seconds for `Animation`.
enum Motion {
    static let durationFast: Double = 0.12
    static let durationBase: Double = 0.22
    static let durationSlow: Double = 0.36

    /// `--ease-out` (principles.md): entrances, cross-fades, progress fills.
    static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

    /// `--ease-standard` (principles.md): color and background changes.
    static func easeStandard(_ duration: Double) -> Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }
}

/// design/principles.md → Materials and Liquid Glass. Geometry is theme-independent
/// (principles.md's own words); only the shadow alpha flips per
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
    /// design/principles.md → Materials and Liquid Glass, `--shadow-md`.
    func shadowMd() -> some View {
        modifier(ShadowMdModifier())
    }
}

/// The sender's code-phrase display: the one documented literal font size
/// in the type scale. Wrapped in `@ScaledMetric` so it keeps tracking Dynamic Type
/// despite the literal.
private struct CodeHeroTextStyle: ViewModifier {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .monospaced))
    }
}

extension View {
    /// design/principles.md → Type, `--type-code-hero` 30/38.
    func codeHeroTextStyle() -> some View {
        modifier(CodeHeroTextStyle())
    }
}
