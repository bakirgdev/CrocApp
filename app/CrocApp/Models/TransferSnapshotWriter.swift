import CrocKit
import Foundation
import OSLog
import Observation
import SwiftData

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Keeps the widget's snapshot file in step with the last finished transfer.
/// Observes the controller from outside, like `TransferNotifier`. With Save
/// Transfer History off the file is deleted and nothing is written, because
/// the widget would otherwise keep a record the user asked not to keep.
@MainActor
final class TransferSnapshotWriter: HistoryChangeObserver {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "widget")

    private struct Observed: Equatable {
        let phase: TransferController.Phase
        let saveHistory: Bool
        let showNames: Bool
    }

    private let controller: TransferController
    private let settings: AppSettings
    private let store: TransferSnapshotStore?
    private let reload: @MainActor () -> Void
    private let now: () -> Date
    /// The last snapshot with its name, kept so the switch can bring the
    /// name back after it was hidden. The file never holds it while off.
    private var current: TransferSnapshot?
    private var lastPhase: TransferController.Phase = .idle
    /// nil until the first change, so a launch with history off clears once.
    private var lastSaveHistory: Bool?
    private var task: Task<Void, Never>?

    init(
        controller: TransferController, settings: AppSettings,
        store: TransferSnapshotStore? = .shared,
        reload: @escaping @MainActor () -> Void = TransferSnapshotWriter.reloadWidgets,
        now: @escaping () -> Date = Date.init
    ) {
        self.controller = controller
        self.settings = settings
        self.store = store
        self.reload = reload
        self.now = now
    }

    func start() {
        guard task == nil else { return }
        current = store?.read()
        let updates = Observations { [controller, settings] in
            Observed(
                phase: controller.phase, saveHistory: settings.saveTransferHistory,
                showNames: settings.systemSurfacesShowFileNames)
        }
        task = Task { [weak self] in
            for await o in updates {
                self?.handle(phase: o.phase, saveHistory: o.saveHistory, showNames: o.showNames)
            }
        }
    }

    /// One observed change. Internal so tests can feed phases without a transfer.
    func handle(phase: TransferController.Phase, saveHistory: Bool, showNames: Bool) {
        defer {
            lastPhase = phase
            lastSaveHistory = saveHistory
        }
        guard let store else { return }
        guard saveHistory else {
            // Once per switch-off, not on every phase change of every transfer.
            guard lastSaveHistory != false else { return }
            current = nil
            // A failed delete leaves the record in place, so it must not be silent.
            do { try store.clear() } catch {
                Self.log.error(
                    "snapshot clear failed: \(String(describing: error), privacy: .public)")
            }
            reload()
            return
        }
        if phase != lastPhase,
            let finished = Self.snapshot(
                for: phase, direction: controller.direction,
                names: controller.direction == .send
                    ? controller.sentItemNames : controller.offeredFileNames,
                showNames: true, date: now())
        {
            current = finished
        }
        guard let current else { return }
        let shown = showNames ? current : current.withoutName
        guard shown != store.read() else { return }
        do { try store.write(shown) } catch {
            Self.log.error("snapshot write failed: \(String(describing: error), privacy: .public)")
        }
        reload()
    }

    /// Clearing History or deleting a record must not leave the widget showing
    /// the transfer. A deletion cannot say whether it was the newest record,
    /// so it clears the snapshot whichever record went; the next transfer
    /// writes a new one.
    func historyDidClear() { forget() }
    func historyDidDelete() { forget() }
    func historyDidAdd(_ record: TransferRecord) {}
    func historyDidRemove(_ ids: [PersistentIdentifier]) {}

    private func forget() {
        current = nil
        do { try store?.clear() } catch {
            Self.log.error("snapshot clear failed: \(String(describing: error), privacy: .public)")
        }
        reload()
    }

    /// A snapshot for a terminal phase; nil while a transfer runs or after a reset.
    static func snapshot(
        for phase: TransferController.Phase, direction: TransferController.Direction,
        names: [String], showNames: Bool, date: Date
    ) -> TransferSnapshot? {
        let outcome: TransferSnapshot.Outcome
        var count = names.count
        switch phase {
        case .done(let summary, _):
            outcome = summary.success ? .done : .failed
            if summary.files > 0 { count = summary.files }
        case .stored: outcome = .done
        case .failed(let failure): outcome = failure.endedByUser ? .stopped : .failed
        default: return nil
        }
        return TransferSnapshot(
            direction: direction == .send ? .send : .receive, outcome: outcome,
            itemCount: count,
            name: TransferSnapshot.name(from: names, showNames: showNames), date: date)
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
