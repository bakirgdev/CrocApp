import Croc
import Foundation

/// A relay this process runs: what `RelayHost` offers, and what the app's tests
/// stand in for.
public protocol RelayHandle: Sendable {
    /// The relay's ports, the control port first.
    var ports: [Int] { get }
    func stop()
}

/// A croc relay served by this process (`StartRelay` in `crocmobile/relayhost.go`),
/// on the croc CLI's `relay` port layout. It runs beside a transfer.
public final class RelayHost: RelayHandle, @unchecked Sendable {
    /// How many ports a relay uses, counted from its base port.
    public static var portCount: Int { Int(CrocmobileRelayPortCount) }

    /// The base ports `start` accepts.
    public static var basePortRange: ClosedRange<Int> { 1...(65_535 - portCount + 1) }

    private let handle: CrocmobileRelayHost
    public let ports: [Int]

    private init(handle: CrocmobileRelayHost) {
        self.handle = handle
        ports = handle.ports().split(separator: ",").compactMap { Int($0) }
    }

    /// Listens on `port` and the next three ports, on every interface. A blank
    /// `password` means croc's default, which anyone can use. Throws an
    /// `EngineFailure`: `.portInUse` for a taken port, `.invalidSetting` for a
    /// base port outside `basePortRange`. `onStopped` runs, on any thread, if
    /// the relay stops by itself; never after `stop()`.
    public static func start(
        port: Int, password: String, onStopped: @escaping @Sendable (EngineFailure) -> Void
    ) throws -> RelayHost {
        let bridge = RelayBridge(onStopped: onStopped)
        var error: NSError?
        guard let handle = CrocmobileStartRelay("", port, password, bridge, &error) else {
            throw EngineFailure(payload: error?.localizedDescription)
        }
        return RelayHost(handle: handle)
    }

    /// Closes the relay's ports. Safe to repeat.
    public func stop() { handle.stop() }
}

private final class RelayBridge: NSObject, CrocmobileRelayDelegateProtocol, @unchecked Sendable {
    private let onStopped: @Sendable (EngineFailure) -> Void

    init(onStopped: @escaping @Sendable (EngineFailure) -> Void) {
        self.onStopped = onStopped
    }

    func onRelayStopped(_ failureJSON: String?) {
        onStopped(EngineFailure(payload: failureJSON))
    }
}

/// The IP versions `RelayCheck` probes separately.
public enum RelayFamily: String, Sendable, CaseIterable {
    case ipv4 = "4"
    case ipv6 = "6"
}

/// What one probe of a relay over one IP version found.
public struct RelayCheckResult: Sendable, Equatable {
    public enum Verdict: Sendable, Equatable {
        /// Reachable, and croc's handshake accepted the password.
        case ok
        /// The relay's name has no address of this IP version.
        case noAddress
        /// No connection: the name did not resolve, or the port refused or timed out.
        case unreachable
        /// Reachable, and the relay rejected the password.
        case badPassword
        /// Reachable, and it accepted the password, but it turned the probe away
        /// for now (rate limit or a full room).
        case busy
        /// Reachable, but it did not answer like a croc relay.
        case notARelay
        /// The address is not host:port.
        case invalidAddress
    }

    public let family: RelayFamily
    /// The address probed, when the name resolved.
    public let ip: String?
    /// How long the TCP connection took, when it was made.
    public let latencyMs: Double?
    public let verdict: Verdict

    public init(family: RelayFamily, ip: String?, latencyMs: Double?, verdict: Verdict) {
        self.family = family
        self.ip = ip
        self.latencyMs = latencyMs
        self.verdict = verdict
    }
}

/// Probes a relay without starting a transfer (`CheckRelay` in
/// `crocmobile/relaycheck.go`): it connects, then runs croc's own relay
/// handshake, which is where the relay accepts or rejects the password.
public enum RelayCheck {
    private struct Payload: Decodable {
        let ip: String?
        let reachable: Bool
        let latencyMs: Double?
        let code: String?
    }

    /// Blocks up to five seconds off the caller's thread. Never throws: every
    /// outcome is a verdict. A blank `password` means croc's default. The
    /// password never leaves the process, and the result never repeats it.
    public static func run(
        address: String, password: String, family: RelayFamily
    ) async -> RelayCheckResult {
        let json = await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            DispatchQueue.global().async {
                cont.resume(returning: CrocmobileCheckRelay(address, password, family.rawValue))
            }
        }
        return decode(json, family: family)
    }

    static func decode(_ json: String, family: RelayFamily) -> RelayCheckResult {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)) else {
            return RelayCheckResult(family: family, ip: nil, latencyMs: nil, verdict: .notARelay)
        }
        let verdict: RelayCheckResult.Verdict
        switch payload.code ?? "" {
        case "": verdict = payload.reachable ? .ok : .unreachable
        case "noAddress": verdict = .noAddress
        case "relayUnreachable": verdict = .unreachable
        case "badPassword": verdict = .badPassword
        case "busy": verdict = .busy
        case "invalidSetting": verdict = .invalidAddress
        default: verdict = payload.reachable ? .notARelay : .unreachable
        }
        return RelayCheckResult(
            family: family, ip: payload.ip, latencyMs: payload.latencyMs, verdict: verdict)
    }
}
