import Accessibility
import SwiftUI

/// Large centered result (transfer done / failed). design/components.md →
/// StatusBlock.
struct StatusBlock: View {
    enum Kind {
        case success
        case error

        var color: Color {
            switch self {
            case .success: .statusSuccess
            case .error: .statusError
            }
        }

        var tint: Color {
            switch self {
            case .success: .statusSuccessTint
            case .error: .statusErrorTint
            }
        }

        // design/iconography.md → Shared meanings: success and error.
        var symbolName: String {
            switch self {
            case .success: "checkmark.circle"
            case .error: "exclamationmark.circle.fill"
            }
        }
    }

    let kind: Kind
    let title: String
    var detail: String?

    // components.md → StatusBlock: a 64 circle holding a 34 glyph, scaled with
    // Dynamic Type so the glyph never outgrows its circle.
    @ScaledMetric(relativeTo: .title) private var circleSize: CGFloat =
        ComponentMetrics.statusBlockCircle
    @ScaledMetric(relativeTo: .title) private var glyphSize: CGFloat =
        ComponentMetrics.statusBlockGlyph

    var body: some View {
        VStack(spacing: Spacing.space3) {
            ZStack {
                Circle()
                    .fill(kind.tint)
                    .frame(width: circleSize, height: circleSize)
                // Decorative: the title states the outcome in words, never
                // color alone (components.md → StatusBlock).
                Image(systemName: kind.symbolName)
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(kind.color)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(Spacing.space6)
        // Appears in place of the progress screen, so VoiceOver focus has
        // nothing to land on; announce the outcome as StatusBanner does.
        .onAppear {
            let message = [title, detail].compactMap { $0 }.joined(separator: ". ")
            AccessibilityNotification.Announcement(message).post()
        }
    }
}
