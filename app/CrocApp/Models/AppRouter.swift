import Foundation
import Observation

/// App-wide navigation plus externally-injected send payloads (window drop,
/// dock-icon drop, menu commands). Singleton: NSApplicationDelegate and menu
/// Commands live outside the SwiftUI environment graph and need a stable
/// reference.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Route: Hashable {
        case send, receive, settings, advancedSettings, howItWorks, history
    }

    var path: [Route] = []
    /// URLs waiting for SendView to pick up into its staged list.
    var pendingSendURLs: [URL] = []
    /// Text waiting for SendView to stage in its text mode. Like the URLs,
    /// it only stages: it never sends.
    var pendingSendText: String?
    /// A receive link waiting for ReceiveView to prefill from it. Opening a
    /// link never connects: the user taps Receive.
    var pendingReceive: TransferLink?

    #if os(macOS)
    enum SettingsTab: Hashable { case general, advanced }
    /// The Settings window's tab, so Open Settings on a failure lands on the
    /// tab its fix lives in.
    var settingsTab: SettingsTab = .general
    #endif

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

    /// Text staged while SendView is away accumulates, like the URLs; empty
    /// text stages nothing.
    func openSend(text: String) {
        guard !text.isEmpty else { return }
        pendingSendText = Self.appending(text, to: pendingSendText ?? "")
        if !isBusy, path != [.send] { path = [.send] }
    }

    /// Staged text goes after what is already there, on its own line.
    nonisolated static func appending(_ new: String, to existing: String) -> String {
        existing.isEmpty ? new : existing + "\n" + new
    }

    /// Same busy rule as openSend: a link that arrives mid-transfer is kept
    /// for the next time Receive is shown, without pulling the user away.
    func open(_ link: TransferLink) {
        pendingReceive = link
        if !isBusy { openReceive() }
    }

    func openReceive() {
        if path != [.receive] { path = [.receive] }
    }
}
