#if os(macOS)
import AppKit
import CrocKit
import Foundation
import Observation

/// Runs the relay this Mac offers to other devices (`RelayHost`). Off by
/// default: it starts only when the user turns it on, or at launch when they
/// turned on "Start relay at launch". While it runs the app listens on the
/// network, so it stops when the app quits.
@MainActor
@Observable
final class RelayHostController {
    enum State: Equatable {
        case stopped
        case running(ports: [Int])
        /// Start failed or the relay stopped by itself; words for the user.
        case failed(TransferFailure)
    }

    typealias Starter = (Int, String, @escaping @Sendable (EngineFailure) -> Void) throws
        -> any RelayHandle

    private(set) var state = State.stopped

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let starter: Starter
    @ObservationIgnored private var handle: (any RelayHandle)?
    /// Counts starts. A stop callback carries the number of the start it
    /// belongs to, so one from a stopped relay never stops a newer one.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var quitObserver: (any NSObjectProtocol)?

    init(
        settings: AppSettings,
        starter: @escaping Starter = { port, password, onStopped in
            try RelayHost.start(port: port, password: password, onStopped: onStopped)
        },
        stopsAtQuit: Bool = true
    ) {
        self.settings = settings
        self.starter = starter
        if stopsAtQuit {
            quitObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
        }
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// The setting is off unless the user turned it on.
    func startAtLaunchIfWanted() {
        if settings.relayHostAtLaunch { start() }
    }

    func start() {
        guard handle == nil else { return }
        if let error = AppSettings.relayHostPortError(settings.relayHostPort) {
            state = .failed(
                TransferFailure(
                    title: String(localized: "The relay port can't be used"), detail: error,
                    remedy: nil))
            return
        }
        generation += 1
        let generation = generation
        do {
            let started = try starter(
                settings.relayHostPort,
                settings.relayHostPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            ) { [weak self] failure in
                Task { @MainActor in self?.stoppedByItself(failure, generation: generation) }
            }
            handle = started
            state = .running(ports: started.ports)
        } catch {
            let failure = error as? EngineFailure ?? EngineFailure(code: .other, message: "")
            state = .failed(TransferFailure(failure, situation: .init()))
        }
    }

    func stop() {
        handle?.stop()
        handle = nil
        state = .stopped
    }

    func setRunning(_ on: Bool) {
        if on { start() } else { stop() }
    }

    private func stoppedByItself(_ failure: EngineFailure, generation: Int) {
        guard handle != nil, generation == self.generation else { return }
        handle?.stop()
        handle = nil
        state = .failed(TransferFailure(failure, situation: .init()))
    }
}
#endif
