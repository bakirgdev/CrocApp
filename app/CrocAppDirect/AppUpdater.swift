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
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    private init() {
        let updater = controller.updater
        canCheckForUpdates = updater.canCheckForUpdates
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
