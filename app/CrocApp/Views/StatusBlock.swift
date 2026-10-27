import Accessibility
import CrocKit
import SwiftUI

/// Large centered result (transfer done / failed). design/components.md →
/// StatusBlock.
struct StatusBlock: View {
    enum Kind {
        case success
        case error
        /// The user's own Cancel or Decline, or a link they revoked: not a
        /// failure (content.md → Errors), so neither red nor green.
        case neutral

        var fill: AnyShapeStyle {
            switch self {
            case .success: AnyShapeStyle(Color.statusSuccessTint)
            case .error: AnyShapeStyle(Color.statusErrorTint)
            // --color-fill-tertiary is the system fill ladder (swiftui.md → Not mirrored).
            case .neutral: AnyShapeStyle(.fill.tertiary)
            }
        }

        var glyphColor: Color {
            switch self {
            case .success: .statusSuccess
            case .error: .statusError
            case .neutral: .textSecondary
            }
        }

        // design/iconography.md → Shared meanings: success and error; App
        // only: cancelled.
        var symbolName: String {
            switch self {
            case .success: "checkmark.circle"
            case .error: "exclamationmark.circle.fill"
            case .neutral: "slash.circle"
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
                    .fill(kind.fill)
                    .frame(width: circleSize, height: circleSize)
                // Decorative: the title states the outcome in words, never
                // color alone (components.md → StatusBlock).
                Image(systemName: kind.symbolName)
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(kind.glyphColor)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
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

// The outcome of each terminal phase, here rather than in a screen, so every
// surface that shows a result (the transfer screen, the menu bar window) says
// it the same way.
extension StatusBlock {
    /// A failed transfer. The user's own Cancel or Decline is neutral.
    init(failure: TransferFailure) {
        self.init(
            kind: failure.endedByUser ? .neutral : .error, title: failure.title,
            detail: failure.detail)
    }

    /// A finished transfer. One that croc did not mark successful is a
    /// failure with its next step (`TransferFailure.finishedWithProblems`).
    init(
        summary: Summary, receivedText: String?, direction: TransferController.Direction
    ) {
        if !summary.success {
            self.init(failure: .finishedWithProblems(direction: direction))
        } else if receivedText != nil {
            self.init(kind: .success, title: String(localized: "Received text"))
        } else {
            self.init(
                kind: .success, title: String(localized: "Transfer complete"),
                detail: inflected(
                    AttributedString(
                        localized:
                            "^[\(summary.files) file](inflect: true) • \(summary.totalSize.formatted(.byteCount(style: .file)))"
                    )))
        }
    }

    /// A stored upload's link is ready to share.
    init(receipt: StoredReceipt) {
        self.init(
            kind: .success, title: String(localized: "Link ready"),
            detail: inflected(
                AttributedString(
                    localized:
                        "Works until \(receipt.expiresAt.formatted(date: .abbreviated, time: .shortened)), for ^[\(receipt.downloads) download](inflect: true)"
                )))
    }
}

#Preview("Kinds") {
    VStack {
        StatusBlock(kind: .success, title: "Transfer complete", detail: "3 files • 24 MB")
        StatusBlock(failure: .cancelledByUser)
        StatusBlock(
            failure: TransferFailure(
                title: "Couldn't reach the relay", detail: "Check your internet connection.",
                remedy: .tryAgain))
    }
}
