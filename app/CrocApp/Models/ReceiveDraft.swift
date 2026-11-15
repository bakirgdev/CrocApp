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
    /// The request Receive started, so a finished transfer empties only the draft it came from.
    @ObservationIgnored var started: TransferRequest?

    /// Empties the code or link `request` used, once it ended in done. A failure
    /// or a cancel keeps it: Try Again reuses it.
    func finish(_ request: TransferRequest?) {
        guard let request, request == started else { return }
        started = nil
        switch request {
        case .receive(let sent, _, _):
            // A link opened while the transfer ran stays for the next one.
            if code.trimmingCharacters(in: .whitespacesAndNewlines) == sent { code = "" }
        case .storedReceive(let sent, _, _):
            if storedLink == sent { storedLink = nil }
        case .sendFiles, .sendText, .storedSend:
            break
        }
    }

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
