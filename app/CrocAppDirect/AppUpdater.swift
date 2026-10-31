import Observation
import Sparkle
import SwiftUI

/// Sparkle updater for the Developer ID build. Only the `CrocApp Direct`
/// target compiles this folder and links Sparkle; the App Store build has
/// neither.
@MainActor
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    private(set) var canCheckForUpdates: Bool
    /// Sparkle keeps this in the app's defaults. It starts off: Sparkle asks
    /// on the second launch before it checks, and this switch is the same choice.
    var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    private init() {
        let updater = controller.updater
        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        // Sparkle documents `canCheckForUpdates` as KVO-compliant. The change
        // can arrive on any thread, so hop to the main actor before writing
        // the observed property.
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: .new) {
            [weak self] _, change in
            guard let canCheck = change.newValue else { return }
            Task { @MainActor in self?.canCheckForUpdates = canCheck }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Sparkle's own prompt can change the setting while Settings is closed.
    func refresh() {
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }
}

struct UpdateCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesButton()
        }
    }
}

private struct CheckForUpdatesButton: View {
    private let updater = AppUpdater.shared

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}

/// The Settings row for the update check, which is the one thing in the
/// Direct build that contacts a server of ours.
struct UpdateSettingsSection: View {
    @State private var updater = AppUpdater.shared

    var body: some View {
        Section {
            Toggle("Check for Updates Automatically", isOn: $updater.automaticallyChecksForUpdates)
        } footer: {
            Text(
                "CrocApp asks github.com for a newer version about once a day. It sends no system profile and no transfer data. Choose Check for Updates in the CrocApp menu to check once."
            )
            .foregroundStyle(Color.textSecondary)
        }
        .onAppear { updater.refresh() }
    }
}
