import Accessibility
import SwiftUI

/// Inline advisory banner: a glyph in the kind color, a title, an optional detail and action.
struct StatusBanner: View {
    enum Kind {
        case info
        case warning
        case error
        case success

        var color: Color {
            switch self {
            case .info: .accentColor
            case .warning: .orange
            case .error: .red
            case .success: .green
            }
        }

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
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                // Not drawn in the kind color: on its own tint that measures
                // 1.96-2.95:1 in light.
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderless)
                        #if os(iOS)
                    // A borderless button is as tall as its text, under the 44 pt
                    // minimum (design/principles.md).
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
                        #endif
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            // Decorative: the title carries the meaning.
            Image(systemName: kind.symbolName)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
        }
        .padding()
        .background(kind.color.opacity(0.14), in: .rect(cornerRadius: 14))
        // SwiftUI has no live-region trait, so an error is announced to
        // VoiceOver when it appears.
        .onAppear {
            guard kind == .error else { return }
            let message = [title, detail].compactMap { $0 }.joined(separator: ". ")
            AccessibilityNotification.Announcement(message).post()
        }
    }
}
