import CrocKit
import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The four haptic events in design/motion.md → Haptics and sound. iPhone only:
/// iPad's haptics are inconsistent across models and macOS has none.
extension View {
    /// `.sensoryFeedback(trigger:_:)` that stays silent off iPhone and while
    /// the Haptics setting is off. Return nil from `feedback` to skip a change.
    /// On iOS the view needs `AppSettings` in its environment.
    func phoneHaptic<T: Equatable>(
        trigger: T, _ feedback: @escaping (_ oldValue: T, _ newValue: T) -> SensoryFeedback?
    ) -> some View {
        #if os(iOS)
        modifier(PhoneHapticModifier(trigger: trigger, feedback: feedback))
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct PhoneHapticModifier<T: Equatable>: ViewModifier {
    @Environment(AppSettings.self) private var settings
    let trigger: T
    let feedback: (_ oldValue: T, _ newValue: T) -> SensoryFeedback?

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            settings.haptics && UIDevice.current.userInterfaceIdiom == .phone
                ? feedback(old, new) : nil
        }
    }
}
#endif

/// What a phase change means for haptics. Everything else in a running
/// transfer (progress, connecting, waiting) stays silent. A failure the user
/// asked for (Cancel, Decline) is a button press and stays silent too.
enum TransferHaptic: Equatable {
    case completed
    case failed
    case incoming

    init?(_ phase: TransferController.Phase, endedByUser: Bool = false) {
        switch phase {
        case .done(let summary, _): self = summary.success ? .completed : .failed
        case .stored: self = .completed
        case .failed:
            if endedByUser { return nil }
            self = .failed
        case .incoming: self = .incoming
        default: return nil
        }
    }

    var feedback: SensoryFeedback {
        switch self {
        case .completed: .success
        case .failed: .error
        case .incoming: .warning
        }
    }
}
