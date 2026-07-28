import Accessibility
import SwiftUI

/// Inline advisory banner. design/components.md → StatusBanner, lines 144-157.
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

        // iconography.md → Mapping: info/warning/error/success rows.
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

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            // iconography.md line 77: banner leading glyph 19, stroke 2.
            // Decorative — the title carries the meaning (colors.md rule 2).
            Image(systemName: kind.symbolName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // Not drawn in the kind color: on its own tint that measures
                // 1.96-2.95:1 in light (components.md line 157).
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.space5)
        .padding(.vertical, Spacing.space4)
        .background(kind.tint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(kind.color.opacity(0.22), lineWidth: BorderWidth.hairline)
        )
        // components.md line 152: error's `role` is `alert`. SwiftUI has no
        // live-region trait, so a VoiceOver announcement on appearance is
        // the closest native equivalent.
        .onAppear {
            guard kind == .error else { return }
            let message = [title, detail].compactMap { $0 }.joined(separator: ". ")
            AccessibilityNotification.Announcement(message).post()
        }
    }
}
