import Foundation
import Observation

/// What the Receive screen holds before Receive is tapped: the typed code, or
/// the stored link that replaces it. Owned by `AppRouter` for the same reason as
/// `SendDraft`. Filling it never connects: the user taps Receive.
@MainActor
@Observable
final class ReceiveDraft {
    var code = ""
    /// A stored link replaces the code field until cleared.
    var storedLink: URL?

    func apply(_ link: TransferLink) {
        switch link {
        case .code(let linked):
            code = linked
            storedLink = nil
        case .stored(let url):
            storedLink = url
            code = ""
        }
    }
}
