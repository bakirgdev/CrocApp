import SwiftUI

/// The arrow glyph and the word, which always travel together.
/// design/components.md → TransferProgress, Direction header. A Send-as-link
/// transfer says Sending and Receiving too.
struct DirectionHeader: View {
    let direction: TransferController.Direction
    /// The sender waits for the other device: the arrow pulses, and only then
    /// (design/motion.md → Vocabulary, Pulse).
    var pulses = false

    @ScaledMetric(relativeTo: .headline) private var glyphSize: CGFloat = IconSize.small
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.space3) {
            Image(systemName: direction == .send ? "arrow.up" : "arrow.down")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(Color.accentFill)
                .symbolEffect(.pulse, isActive: pulses && !reduceMotion)
                .accessibilityHidden(true)
            Text(direction == .send ? "Sending" : "Receiving")
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
    }
}
