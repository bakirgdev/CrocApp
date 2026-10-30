import SwiftUI

/// A determinate bar that animates at `--dur-base` `--ease-out` and never moves
/// backwards. design/principles.md → Motion. `resetKey` names what the bar
/// measures (the current file, the total size): when it changes, the bar snaps
/// to the new fraction and moves forward from there.
struct ForwardProgressBar: View {
    let fraction: Double
    let resetKey: AnyHashable

    @State private var shown: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(fraction: Double, resetKey: AnyHashable) {
        self.fraction = fraction
        self.resetKey = resetKey
        _shown = State(initialValue: fraction)
    }

    var body: some View {
        ProgressView(value: shown)
            .animation(reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: shown)
            .onChange(of: fraction) { _, new in shown = max(shown, new) }
            .onChange(of: resetKey) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { shown = fraction }
            }
    }
}
