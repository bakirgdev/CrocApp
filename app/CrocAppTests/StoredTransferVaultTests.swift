import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// Receipts carry the upload token and the link key, so they live only in the
/// Keychain. Every test runs over an in-memory `SecretStore`.
@MainActor
@Suite struct StoredTransferVaultTests {
    private static let account = "storedReceipts"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func receipt(_ id: String, expiresIn seconds: TimeInterval = 3600) -> StoredReceipt {
        StoredReceipt(
            id: id, origin: "https://getcroc.com", uploadToken: "token-\(id)",
            link: "https://getcroc.com/s/\(id)#v1.key-\(id)",
            expiresAt: now.addingTimeInterval(seconds), downloads: 1)
    }

    @Test func receiptSurvivesARelaunch() {
        let store = FakeSecretStore()
        let r = receipt("a")
        #expect(StoredTransferVault(secrets: store, now: now).add(r))

        let reopened = StoredTransferVault(secrets: store, now: now)
        #expect(reopened.receipt(id: "a") == r)
        #expect(reopened.receipt(id: "b") == nil)
    }

    @Test func removeDeletesTheItemWhenEmpty() {
        let store = FakeSecretStore()
        let vault = StoredTransferVault(secrets: store, now: now)
        vault.add(receipt("a"))
        vault.add(receipt("b"))

        #expect(vault.remove(id: "a"))
        #expect(StoredTransferVault(secrets: store, now: now).receipt(id: "a") == nil)
        #expect(StoredTransferVault(secrets: store, now: now).receipt(id: "b") != nil)

        vault.remove(id: "b")
        #expect(store.items.isEmpty, "no empty item left behind")
        #expect(vault.remove(id: "missing"), "removing what is not there succeeds")
    }

    @Test func addingTheSameIDReplacesIt() {
        let store = FakeSecretStore()
        let vault = StoredTransferVault(secrets: store, now: now)
        vault.add(receipt("a", expiresIn: 60))
        vault.add(receipt("a", expiresIn: 600))

        let reopened = StoredTransferVault(secrets: store, now: now)
        #expect(reopened.receipt(id: "a")?.expiresAt == now.addingTimeInterval(600))
        vault.remove(id: "a")
        #expect(store.items.isEmpty, "only one copy was stored")
    }

    @Test func expiredReceiptsArePurgedAtLaunch() {
        let store = FakeSecretStore()
        let vault = StoredTransferVault(secrets: store, now: now)
        vault.add(receipt("short", expiresIn: 60))
        vault.add(receipt("long", expiresIn: 7200))

        let later = StoredTransferVault(secrets: store, now: now.addingTimeInterval(3600))
        #expect(later.receipt(id: "short") == nil)
        #expect(later.receipt(id: "long") != nil)
        // The purge was written back, not only applied in memory.
        let fresh = StoredTransferVault(secrets: store, now: now)
        #expect(fresh.receipt(id: "short") == nil)
    }

    /// A failed Keychain write must not destroy receipts stored earlier, and
    /// the new one still works for this launch.
    @Test func failedWriteKeepsEarlierReceipts() {
        let store = FakeSecretStore()
        let vault = StoredTransferVault(secrets: store, now: now)
        vault.add(receipt("a"))
        store.failWrites = true

        #expect(!vault.add(receipt("b")))
        #expect(vault.receipt(id: "b") != nil, "usable until the app quits")

        let reopened = StoredTransferVault(secrets: store, now: now)
        #expect(reopened.receipt(id: "a") != nil)
        #expect(reopened.receipt(id: "b") == nil)
    }

    @Test func unreadableItemStartsEmpty() {
        let store = FakeSecretStore()
        store.items[Self.account] = "not json"

        let vault = StoredTransferVault(secrets: store, now: now)
        #expect(vault.receipt(id: "a") == nil)
        #expect(vault.add(receipt("a")))
        #expect(StoredTransferVault(secrets: store, now: now).receipt(id: "a") != nil)
    }

    /// The token and the link may sit in the vault's own item and nowhere else.
    @Test func secretsStayInTheVaultItem() {
        let store = FakeSecretStore()
        StoredTransferVault(secrets: store, now: now).add(receipt("a"))
        #expect(Array(store.items.keys) == [Self.account])
    }

    @Test func revokeNeedsAnUnexpiredUnrevokedReceipt() throws {
        let vault = StoredTransferVault(secrets: FakeSecretStore(), now: now)
        vault.add(receipt("a"))
        // Nothing is written to these defaults: the test sets no setting.
        let defaults = try #require(UserDefaults(suiteName: "CrocAppTests.\(UUID().uuidString)"))
        let controller = TransferController(
            settings: AppSettings(defaults: defaults, secrets: FakeSecretStore()), vault: vault)
        func record(_ id: String?, expiresIn seconds: TimeInterval = 3600) -> TransferRecord {
            TransferRecord(
                isSend: true, status: .completed, isText: false, fileCount: 1, totalBytes: 1,
                names: ["a.txt"], codeHint: "getcroc.com", bookmarks: [], storedID: id,
                expiresAt: id == nil ? nil : now.addingTimeInterval(seconds))
        }

        #expect(controller.canRevoke(record("a"), now: now))
        #expect(!controller.canRevoke(record(nil), now: now), "a live send")
        #expect(!controller.canRevoke(record("b"), now: now), "no receipt on this device")
        #expect(!controller.canRevoke(record("a", expiresIn: -1), now: now), "expired")
        let revoked = record("a")
        revoked.revokedAt = now
        #expect(!controller.canRevoke(revoked, now: now), "already revoked")
    }
}
