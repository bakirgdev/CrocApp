import Foundation
import Observation

#if os(iOS)
import Network
#endif

// iOS has no official local-network authorization API (verified 2026-07).
// Probe: advertise a Bonjour service and browse for it ourselves — seeing our
// own service means access is granted; a browser stuck in .waiting(error)
// means denied. The probe also triggers the system permission prompt at a
// moment tied to a real transfer, instead of mid-handshake.
@MainActor
@Observable
final class LocalNetworkChecker {
    enum Status { case unknown, granted, denied }
    private(set) var status: Status = .unknown

    #if os(iOS)
    private var started = false

    func checkIfNeeded() {
        guard !started else { return }
        started = true
        Task { [weak self] in
            let granted = await Self.probe(timeoutSeconds: 8)
            guard let self else { return }
            if let granted {
                self.status = granted ? .granted : .denied
            }
        }
    }

    // Returns nil on timeout (state unknown — do not alarm the user).
    // Everything (listener, browser, timeout) runs on the main queue, so the
    // once-guard is a plain Bool — no locking needed.
    private static func probe(timeoutSeconds: Double) async -> Bool? {
        let type = "_crocapp._tcp"
        let name = UUID().uuidString

        let listener: NWListener
        do {
            listener = try NWListener(using: .tcp)
        } catch {
            return nil
        }
        listener.service = NWListener.Service(name: name, type: type)
        listener.newConnectionHandler = { $0.cancel() }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)

        return await withCheckedContinuation { (cont: CheckedContinuation<Bool?, Never>) in
            nonisolated(unsafe) var resumed = false
            // A .waiting browser state can mean the system permission prompt
            // is still pending user response — not yet a real denial. Track
            // it and only treat it as denied if we're still unresolved by
            // the timeout.
            nonisolated(unsafe) var sawWaiting = false
            let finish: @Sendable (Bool?) -> Void = { value in
                guard !resumed else { return }
                resumed = true
                listener.cancel()
                browser.cancel()
                cont.resume(returning: value)
            }
            browser.stateUpdateHandler = { state in
                if case .waiting = state { sawWaiting = true }
                if case .failed = state { finish(false) }
            }
            browser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    if case .service(let sName, _, _, _) = result.endpoint, sName == name {
                        finish(true)
                    }
                }
            }
            listener.stateUpdateHandler = { state in
                if case .failed = state { finish(false) }
            }
            listener.start(queue: .main)
            browser.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
                finish(sawWaiting ? false : nil)
            }
        }
    }
    #else
    func checkIfNeeded() {}
    #endif
}
