import CrocKit
import Foundation
import Observation
import SwiftData

/// What History does to a record, shared by the list and the record's detail.
/// The one state that crosses both screens is which revokes are running, so a
/// revoke started in the detail also disables the list's entry for it.
@MainActor
@Observable
final class HistoryActions {
    private(set) var revoking: Set<PersistentIdentifier> = []

    func isRevoking(_ record: TransferRecord) -> Bool {
        revoking.contains(record.persistentModelID)
    }

    /// Revokes a stored upload's link. Returns the failure text to show, or
    /// nil when the link is revoked. A record that is already being revoked
    /// returns nil: the first call reports for both.
    func revoke(_ record: TransferRecord, with controller: TransferController) async -> String? {
        let id = record.persistentModelID
        guard revoking.insert(id).inserted else { return nil }
        defer { revoking.remove(id) }
        do {
            try await controller.revoke(record)
            return nil
        } catch let failure as EngineFailure {
            return TransferFailure(failure, situation: .init(isStored: true)).text
        } catch {
            return String(localized: "Try again in a moment.")
        }
    }

    /// Stages a past send's files for a new send. False when none of the
    /// originals can be reached any more.
    func resend(_ record: TransferRecord, router: AppRouter) -> Bool {
        // See SecurityScopedBookmark.resolveIfReachable for why the scope
        // must be started before the existence probe -- the send opens its
        // own scope at send time.
        let urls = record.bookmarks.compactMap { data in
            SecurityScopedBookmark.resolveIfReachable(data)
        }
        guard !urls.isEmpty else { return false }
        router.openSend(with: urls)
        return true
    }
}

extension TransferRecord {
    /// The record matches a History search when `query` is part of one of its
    /// file names, ignoring case and diacritics. A blank query matches all.
    func matches(search query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || names.contains { $0.localizedStandardContains(query) }
    }
}
