import SwiftUI

/// Large centered result (transfer done / failed). design/components.md →
/// StatusBlock, lines 161-166.
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

        // iconography.md → Mapping: success/error rows.
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

    var body: some View {
        VStack(spacing: Spacing.space3) {
            ZStack {
                Circle()
                    .fill(kind.tint)
                    .frame(
                        width: ComponentMetrics.statusBlockCircle,
                        height: ComponentMetrics.statusBlockCircle
                    )
                // iconography.md line 80: StatusBlock circle glyph 34, stroke 2.
                // Decorative — the title states the outcome in words, never
                // color alone (components.md line 165).
                Image(systemName: kind.symbolName)
                    .font(.system(size: ComponentMetrics.statusBlockGlyph, weight: .semibold))
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
    }
}
