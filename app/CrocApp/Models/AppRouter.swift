import Foundation
import Observation

#if os(macOS)
import AppKit
#endif

/// App-wide navigation plus the drafts the screens edit. Singleton:
/// NSApplicationDelegate, menu Commands, App Intents and notification taps live
/// outside the SwiftUI environment graph and need a stable reference.
///
/// The tab view (design/principles.md → Platform adaptation) reads `selection`.
/// The drafts live here, above the tab view, so what the user staged or typed
/// survives a tab change and a flip between tab bar and sidebar, and every entry
/// point can fill a screen that is not on display.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// A tab of the tab bar, a row of the sidebar. The Mac has no Settings
    /// tab: its Settings scene stands in.
    enum Screen: Hashable, CaseIterable {
        case send, receive, history, settings

        init(direction: TransferController.Direction) {
            self = direction == .send ? .send : .receive
        }
    }

    /// A page pushed in the Settings tab.
    enum SettingsPage: Hashable { case advanced }

    var selection: Screen = .send
    /// The pages pushed in the Settings tab, so a failure can open Advanced.
    var settingsPath: [SettingsPage] = []
    /// How It Works is a sheet over whichever tab is open.
    var showsHowItWorks = false
    let sendDraft = SendDraft()
    let receiveDraft = ReceiveDraft()

    #if os(macOS)
    /// Opens the main window. The main window's content installs it at
    /// launch (`CrocAppApp`): an `openWindow` action keeps working after the
    /// window closes, which a notification tap or a widget button needs, and
    /// the app may then have no window to show a route in.
    @ObservationIgnored var windowOpener: (() -> Void)?

    /// Brings the app forward with its main window open, also when the user
    /// closed it. Without the opener (not built yet) it asks the system to
    /// reopen the app.
    func showMainWindow() {
        NSApp.activate()
        if let windowOpener {
            windowOpener()
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }

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

    // MARK: - Entry points

    // A drop, a link or staged text that arrives mid-transfer fills its draft
    // and moves nobody: the app never takes the user off a transfer by itself.

    func openSend(with urls: [URL]) {
        sendDraft.add(urls)
        if !isBusy { selection = .send }
    }

    /// Empty text stages nothing.
    func openSend(text: String) {
        sendDraft.append(text: text)
        if !isBusy { selection = .send }
    }

    func open(_ link: TransferLink) {
        receiveDraft.apply(link)
        if !isBusy { openReceive() }
    }

    func openReceive() { selection = .receive }

    /// Shows History. Same busy rule as `openSend(with:)`: a transfer in
    /// progress keeps the screen.
    func openHistory() {
        if !isBusy { selection = .history }
    }

    // MARK: - Menu commands

    // The user chose these, so they navigate even mid-transfer; going to
    // another screen answers nothing and cancels nothing.

    func showHistory() { selection = .history }

    /// A tab on iPhone and iPad. The Mac has its Settings scene instead.
    func showSettings(advanced: Bool = false) {
        settingsPath = advanced ? [.advanced] : []
        selection = .settings
    }

    func showHowItWorks() {
        showsHowItWorks = true
        #if os(macOS)
        showMainWindow()
        #endif
    }
}
