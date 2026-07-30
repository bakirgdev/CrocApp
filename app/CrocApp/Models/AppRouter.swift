import Foundation
import Observation

/// App-wide navigation plus externally-injected send payloads (window drop,
/// dock-icon drop, menu commands). Singleton: NSApplicationDelegate and menu
/// Commands live outside the SwiftUI environment graph and need a stable
/// reference. (Module default actor isolation is MainActor.)
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Route: Hashable { case send, receive, settings, howItWorks, history }

    var path: [Route] = []
    /// URLs waiting for SendView to pick up into its staged list.
    var pendingSendURLs: [URL] = []

    /// Weak: AppRouter.shared is constructed before TransferController
    /// exists, so CrocAppApp.init() attaches it after the fact; weak avoids
    /// a retain cycle since TransferController never needs to reach back.
    private weak var controller: TransferController?

    func attach(controller: TransferController) {
        self.controller = controller
    }

    /// Reads TransferController.isActive live instead of mirroring it via a
    /// separate onChange-maintained flag, so a dock drop landing in the same
    /// update pass as an isActive flip can't navigate mid-transfer-start.
    /// Reading it here still invalidates observers correctly: Observation
    /// tracks the access transitively through this computed property.
    var isBusy: Bool { controller?.isActive ?? false }

    func openSend(with urls: [URL]) {
        for url in urls where !pendingSendURLs.contains(url) {
            pendingSendURLs.append(url)
        }
        if !isBusy, path != [.send] { path = [.send] }
    }

    func openReceive() {
        if path != [.receive] { path = [.receive] }
    }
}
