import CrocKit
import SwiftUI

extension AppRouter.Screen {
    var title: String {
        switch self {
        case .send: String(localized: "Send")
        case .receive: String(localized: "Receive")
        case .history: String(localized: "History")
        case .settings: String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .send: "arrow.up.circle"
        case .receive: "arrow.down.circle"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

/// What the tab of the transfer in flight shows: while the transfer is starting,
/// waiting, asking for an answer or moving bytes. A finished or failed transfer
/// leaves every tab at rest, because the result is on the screen and in a
/// notification. No percent: it would redraw the tab view at every step, and the
/// screen already shows it.
struct TransferTabState: Equatable {
    /// The phase without its payload. A change here is announced once.
    enum Kind: Equatable {
        case connecting, waiting, review, transferring
    }

    let kind: Kind
    let screen: AppRouter.Screen

    init?(phase: TransferController.Phase, direction: TransferController.Direction) {
        switch phase {
        case .starting, .connecting: kind = .connecting
        case .waiting: kind = .waiting
        case .confirmSend, .incoming: kind = .review
        case .transferring: kind = .transferring
        case .idle, .done, .stored, .failed: return nil
        }
        screen = AppRouter.Screen(direction: direction)
    }

    /// The badge on the tab.
    var badge: Text {
        switch kind {
        case .connecting: Text("Connecting")
        case .waiting: Text("Waiting")
        case .review: Text("Review")
        case .transferring: screen == .send ? Text("Sending") : Text("Receiving")
        }
    }

    /// The tab's name and its state ("Send, connecting"), announced when the
    /// state's kind changes.
    var spoken: String {
        let words =
            switch kind {
            case .connecting:
                String(localized: "connecting", comment: "Said after a tab's name.")
            case .waiting:
                String(
                    localized: "waiting for the other device",
                    comment: "Said after a tab's name.")
            case .review:
                String(localized: "needs your answer", comment: "Said after a tab's name.")
            case .transferring:
                String(localized: "transferring", comment: "Said after a tab's name.")
            }
        return String(
            localized: "\(screen.title), \(words)",
            comment: "A tab's name, then its state. Both placeholders are words.")
    }
}
