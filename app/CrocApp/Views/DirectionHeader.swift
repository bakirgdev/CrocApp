import SwiftUI

/// The arrow glyph and the word, which always travel together.
/// A Send-as-link
/// transfer says Sending and Receiving too.
struct DirectionHeader: View {
    let direction: TransferController.Direction
    /// The sender waits for the other device: the arrow pulses, and only then.
    var pulses = false
    /// Files wait for the user's yes: nothing is being received yet, so the word
    /// is the tab's "Review" badge.
    var awaitsAnswer = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(awaitsAnswer ? "Review" : direction == .send ? "Sending" : "Receiving")
        } icon: {
            Image(systemName: direction == .send ? "arrow.up" : "arrow.down")
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: pulses && !reduceMotion)
        }
        .font(.headline)
    }
}
