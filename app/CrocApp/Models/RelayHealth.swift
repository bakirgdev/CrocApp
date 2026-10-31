import CrocKit
import Foundation
import Observation

/// The relay health check: probes the relay the settings point at, over IPv4
/// and IPv6, with the configured password (`RelayCheck`), and words what to
/// change. It starts no transfer and never shows, stores or logs the password.
@MainActor
@Observable
final class RelayHealth {
    struct Row: Identifiable, Equatable {
        let address: String
        let family: RelayFamily
        /// nil while the probe runs.
        var result: RelayCheckResult?
        var id: String { "\(address)/\(family.rawValue)" }
    }

    typealias Checker = @Sendable (String, String, RelayFamily) async -> RelayCheckResult

    private(set) var rows: [Row] = []
    private(set) var isRunning = false
    /// This Mac's relay is not the subject: Local Network Only never uses one.
    let usesNoRelay: Bool

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let checker: Checker

    init(
        settings: AppSettings,
        checker: @escaping Checker = { address, password, family in
            await RelayCheck.run(address: address, password: password, family: family)
        }
    ) {
        self.settings = settings
        self.checker = checker
        usesNoRelay = settings.onlyLocal
    }

    /// An Advanced proxy is set. The check dials the relay directly, so it would
    /// show this device's own address to every relay it probes.
    var usesProxy: Bool {
        [settings.socks5Proxy, settings.httpProxy].contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The relay addresses a transfer would use: the custom ones, else the
    /// public pool (the one a code phrase picks is not known before a transfer).
    var targets: [String] {
        guard !settings.onlyLocal else { return [] }
        let custom = [
            (settings.relayAddress, RelayDefaults.address),
            (settings.relayAddress6, RelayDefaults.address6),
        ]
        .map { ($0.0.trimmingCharacters(in: .whitespacesAndNewlines), $0.1) }
        .filter { !$0.0.isEmpty && $0.0 != $0.1 }
        .map(\.0)
        return custom.isEmpty ? RelayDefaults.publicPool : custom
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let password = settings.relayPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        rows = targets.flatMap { address in
            RelayFamily.allCases.map { Row(address: address, family: $0, result: nil) }
        }
        let checker = checker
        await withTaskGroup(of: (String, RelayCheckResult).self) { group in
            for row in rows {
                let (id, address, family) = (row.id, row.address, row.family)
                group.addTask { (id, await checker(address, password, family)) }
            }
            for await (id, result) in group {
                if let index = rows.firstIndex(where: { $0.id == id }) {
                    rows[index].result = result
                }
            }
        }
    }

    /// What to change, once every probe has answered: the failures the rows
    /// show, in the words a failed transfer uses (`TransferFailure`).
    var advice: [TransferFailure] {
        let results = rows.compactMap(\.result)
        guard results.count == rows.count, !rows.isEmpty else { return [] }
        var advice: [TransferFailure] = []
        if results.contains(where: { $0.verdict == .badPassword }) {
            advice.append(Self.failure(.badPassword))
        }
        if results.contains(where: { $0.verdict == .notARelay }) {
            advice.append(Self.notARelay)
        }
        if results.contains(where: { $0.verdict == .busy }) {
            advice.append(Self.busy)
        }
        // A relay with an address of one IP version at least is fine; trouble is
        // an address none of whose probes got through.
        let unreachable = Dictionary(grouping: rows, by: \.address).values.contains { group in
            group.allSatisfy {
                [.unreachable, .noAddress, .invalidAddress].contains($0.result?.verdict)
            }
        }
        if unreachable {
            advice.append(Self.failure(.relayUnreachable))
        }
        return advice
    }

    /// At least one probe got a full croc handshake and none failed.
    var isHealthy: Bool {
        let results = rows.compactMap(\.result)
        return results.count == rows.count && results.contains { $0.verdict == .ok }
            && advice.isEmpty
    }

    private static func failure(_ code: EngineFailure.Code) -> TransferFailure {
        TransferFailure(EngineFailure(code: code, message: ""), situation: .init())
    }

    static var busy: TransferFailure {
        TransferFailure(
            title: String(localized: "The relay is busy"),
            detail: String(
                localized: "It is working, but turned this check away. Try again in a minute."),
            remedy: nil)
    }

    static var notARelay: TransferFailure {
        TransferFailure(
            title: String(localized: "That address isn't a croc relay"),
            detail: String(
                localized: "Check the relay address and port in Settings, and that croc runs there."
            ),
            remedy: .openSettings(.general))
    }
}
