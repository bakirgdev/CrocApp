import Accessibility
import SwiftUI

/// Inline advisory banner. design/components.md → StatusBanner.
struct StatusBanner: View {
    enum Kind {
        case info
        case warning
        case error
        case success

        var color: Color {
            switch self {
            case .info: .statusInfo
            case .warning: .statusWarning
            case .error: .statusError
            case .success: .statusSuccess
            }
        }

        var tint: Color {
            switch self {
            case .info: .statusInfoTint
            case .warning: .statusWarningTint
            case .error: .statusErrorTint
            case .success: .statusSuccessTint
            }
        }

        // design/implementation.md → Icons: info/warning/error/success.
        var symbolName: String {
            switch self {
            case .info: "info.circle"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "exclamationmark.circle.fill"
            case .success: "checkmark.circle"
            }
        }
    }

    let kind: Kind
    let title: String
    var detail: String?
    /// Optional trailing `plain` action (components.md → StatusBanner).
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    // components.md → StatusBanner: glyph at 19, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .subheadline) private var glyphSize: CGFloat = 19

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            // Decorative: the title carries the meaning (principles.md → Contrast, rule 2).
            Image(systemName: kind.symbolName)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.space1) {
                // Not drawn in the kind color: on its own tint that measures
                // 1.96-2.95:1 in light (components.md → StatusBanner).
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonVariant(.plain)
                        .hitTarget()
                }
            }
            // A banner fills its column, like the buttons it sits beside.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.space5)
        .padding(.vertical, Spacing.space4)
        .background(kind.tint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(
                    kind.color.opacity(ComponentMetrics.statusBorderOpacity),
                    lineWidth: BorderWidth.hairline)
        )
        // components.md → StatusBanner: error is announced. SwiftUI has no
        // live-region trait, so a VoiceOver announcement on appearance is
        // the closest native equivalent.
        .onAppear {
            guard kind == .error else { return }
            let message = [title, detail].compactMap { $0 }.joined(separator: ". ")
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

extension AnyTransition {
    /// design/principles.md → Motion: a banner fades in while moving
    /// `--space-3` down into place, and fades out quicker. Nothing moves under
    /// Reduce Motion.
    static func statusBannerInsert(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -Spacing.space3))
                .animation(Motion.easeOut(Motion.durationBase)),
            removal: .opacity.animation(Motion.easeStandard(Motion.durationFast)))
    }
}
