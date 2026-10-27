import Foundation
import Observation

/// App-wide navigation plus externally-injected send payloads (window drop,
/// dock-icon drop, menu commands). Singleton: NSApplicationDelegate and menu
/// Commands live outside the SwiftUI environment graph and need a stable
/// reference.
///
/// One `path` serves both layouts (design/platforms.md → Layout by width). In
/// compact width it is the `NavigationStack` path under Home. In regular width
/// its first element is the sidebar row and the rest are the screens pushed in
/// that row's detail, so every entry point that sets `path` lands correctly in
/// either layout.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Route: Hashable {
        case send, receive, settings, advancedSettings, howItWorks, history
    }

    /// A row of the regular-width sidebar, in the order it is drawn.
    enum SidebarItem: Hashable, CaseIterable, Identifiable {
        case send, receive, history, settings

        var id: Self { self }

        /// The Mac keeps Settings in its Settings scene, never as a row.
        static var rows: [SidebarItem] {
            #if os(macOS)
            [.send, .receive, .history]
            #else
            allCases
            #endif
        }

        var route: Route {
            switch self {
            case .send: .send
            case .receive: .receive
            case .history: .history
            case .settings: .settings
            }
        }

        init?(route: Route) {
            guard let item = Self.rows.first(where: { $0.route == route }) else { return nil }
            self = item
        }

        /// The row a transfer of `direction` shows its state on.
        init(direction: TransferController.Direction) {
            self = direction == .send ? .send : .receive
        }
    }

    var path: [Route] = []
    /// Set by `ContentView` from the size class: whether the sidebar layout
    /// is the one on screen.
    var isRegularWidth = false
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

    // MARK: - Regular width

    /// The sidebar row the path starts at. A path that starts anywhere else (a
    /// screen pushed from Home before the window grew, a route the Mac has no
    /// row for) leaves Send selected.
    var selection: SidebarItem {
        get { path.first.flatMap { SidebarItem(route: $0) } ?? .send }
        set { path = [newValue.route] }
    }

    /// The screens pushed inside the selected row's detail.
    var detailPath: [Route] {
        get { startsAtRow ? Array(path.dropFirst()) : path }
        set { path = (startsAtRow ? Array(path.prefix(1)) : []) + newValue }
    }

    private var startsAtRow: Bool {
        path.first.flatMap { SidebarItem(route: $0) } != nil
    }

    // MARK: - Entry points

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

    // MARK: - Menu commands

    // The user chose these, so they navigate even mid-transfer; going to
    // another screen answers nothing and cancels nothing.

    func showHistory() { path = [.history] }

    /// A row on iPad, a push from Home in compact width. The Mac has its
    /// Settings scene instead.
    func showSettings() { path = [.settings] }

    /// Pushed on whatever is open, in the detail column or the stack, so Back
    /// returns to it.
    func showHowItWorks() {
        if path.last != .howItWorks { push([.howItWorks]) }
    }

    /// Pushes `routes` on whatever is open, so Back returns to it. In regular
    /// width a path that does not start at a row (an empty one at launch)
    /// first takes the row the sidebar shows, or a pushed `.settings` would be
    /// read as the Settings row and replace the screen it was pushed from.
    func push(_ routes: [Route]) {
        if isRegularWidth, !startsAtRow { path.insert(selection.route, at: 0) }
        path.append(contentsOf: routes)
    }
}
