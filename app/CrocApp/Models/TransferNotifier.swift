import CrocKit
import Foundation
import Observation

/// What a local notification says. Built only from a phase, so it can never
/// carry a code phrase or a link (design: `knowledge/app-ui-architecture.md`,
/// "System surfaces").
struct TransferNotice: Equatable {
    let title: String
    let body: String?
    /// Which screen a tap opens.
    let direction: TransferController.Direction
}

/// The system's notification center, as far as transfers use it.
@MainActor
protocol NotificationPosting {
    /// Asks the system for permission; a no-op once the user has answered.
    func requestAuthorization() async
    func post(_ notice: TransferNotice)
    func removeDelivered()
}

/// Turns `TransferController` phase changes into local notifications and
/// Dock-tile state. It observes the controller from outside, so the controller
/// knows nothing about either.
@MainActor
final class TransferNotifier {
    private struct Snapshot: Equatable {
        let phase: TransferController.Phase
        let percent: Int?
        let enabled: Bool
    }

    private let controller: TransferController
    private let settings: AppSettings
    private let center: any NotificationPosting
    private let isAppActive: @MainActor () -> Bool
    /// Mac only: the Dock tile's badge text.
    private let setDockBadge: @MainActor (String?) -> Void
    private var lastNotice: TransferNotice?
    private var lastEnabled: Bool?
    private var lastPhase: TransferController.Phase = .idle
    private var task: Task<Void, Never>?

    init(
        controller: TransferController, settings: AppSettings, center: any NotificationPosting,
        isAppActive: @escaping @MainActor () -> Bool,
        setDockBadge: @escaping @MainActor (String?) -> Void = { _ in }
    ) {
        self.controller = controller
        self.settings = settings
        self.center = center
        self.isAppActive = isAppActive
        self.setDockBadge = setDockBadge
    }

    func start() {
        guard task == nil else { return }
        let updates = Observations { [controller, settings] in
            Snapshot(
                phase: controller.phase,
                percent: SidebarRowState.percent(of: controller.progress),
                enabled: settings.notificationsEnabled)
        }
        task = Task { [weak self] in
            for await s in updates {
                self?.handle(phase: s.phase, percent: s.percent, enabled: s.enabled)
            }
        }
    }

    /// One observed change. Internal so tests can feed phases without a transfer.
    func handle(phase: TransferController.Phase, percent: Int?, enabled: Bool) {
        setDockBadge(Self.dockBadge(for: phase, percent: percent))
        defer {
            lastEnabled = enabled
            lastPhase = phase
        }
        guard enabled else { return }

        // Asked in context: when the switch is turned on, or when the first
        // transfer starts. The system shows its prompt only the first time.
        let started = phase == .starting && lastPhase != .starting
        if started || lastEnabled == false { Task { await center.requestAuthorization() } }

        let notice = Self.notice(
            for: phase, direction: controller.direction,
            offeredNames: controller.offeredFileNames,
            showNames: settings.notificationsShowFileNames)
        defer { lastNotice = notice }
        guard let notice else {
            // The request was answered or the result dismissed.
            if lastNotice != nil { center.removeDelivered() }
            return
        }
        if notice != lastNotice, !isAppActive() { center.post(notice) }
    }

    /// The Dock tile's badge: the percent while bytes move, "1" while a
    /// request waits for an answer, nothing otherwise.
    static func dockBadge(for phase: TransferController.Phase, percent: Int?) -> String? {
        if phase.needsAnswer { return "1" }
        guard phase == .transferring, let percent else { return nil }
        return "\(percent)%"
    }

    /// Which phases notify, and with what words. File names appear only with
    /// `showNames`; a failure shows its title, which names no file.
    static func notice(
        for phase: TransferController.Phase, direction: TransferController.Direction,
        offeredNames: [String], showNames: Bool
    ) -> TransferNotice? {
        func make(_ title: String, names: [String] = []) -> TransferNotice {
            TransferNotice(
                title: title, body: showNames ? nameText(names) : nil, direction: direction)
        }
        switch phase {
        case .done(let summary, _):
            return make(
                summary.success
                    ? String(localized: "Transfer complete")
                    : String(localized: "Transfer finished with errors"),
                names: offeredNames)
        case .stored:
            return make(String(localized: "Link ready"))
        case .failed(let failure):
            guard !failure.endedByUser else { return nil }
            return TransferNotice(
                title: String(localized: "Transfer failed"), body: failure.title,
                direction: direction)
        case .incoming(let list, _, _):
            return make(
                String(localized: "Files are waiting for your answer"),
                names: list.files.map(\.name))
        case .confirmSend:
            return make(String(localized: "The other device is waiting for you to send"))
        case .idle, .starting, .waiting, .connecting, .transferring:
            return nil
        }
    }

    private static func nameText(_ names: [String]) -> String? {
        switch names.count {
        case 0: nil
        case 1: names[0]
        default: inflected(AttributedString(localized: "^[\(names.count) file](inflect: true)"))
        }
    }
}
