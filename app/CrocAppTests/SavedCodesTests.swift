import Foundation
import Testing

@testable import CrocApp

@MainActor
struct SavedCodesTests {
    @Test func startsEmptyAndNothingIsSavedUnasked() {
        let secrets = FakeSecretStore()
        let saved = SavedCodes(secrets: secrets)
        #expect(saved.codes.isEmpty)
        #expect(secrets.items.isEmpty)
    }

    @Test func savesTrimsAndSortsByName() {
        let saved = SavedCodes(secrets: FakeSecretStore())
        saved.save(SavedCode(name: " Zoe ", code: " zoe-code-1 "))
        saved.save(SavedCode(name: "alice", code: "alice-code"))
        #expect(saved.codes.map(\.name) == ["alice", "Zoe"])
        #expect(saved.codes.last?.code == "zoe-code-1")
    }

    @Test func refusesBlankNameAndShortCode() {
        let secrets = FakeSecretStore()
        let saved = SavedCodes(secrets: secrets)
        saved.save(SavedCode(name: "  ", code: "long-enough"))
        saved.save(SavedCode(name: "Bob", code: "short"))
        #expect(saved.codes.isEmpty)
        #expect(secrets.items.isEmpty)
    }

    @Test func renameKeepsIdentity() {
        let saved = SavedCodes(secrets: FakeSecretStore())
        let original = SavedCode(name: "Old", code: "same-code")
        saved.save(original)
        saved.save(SavedCode(id: original.id, name: "New", code: "same-code"))
        #expect(saved.codes.map(\.name) == ["New"])
    }

    @Test func persistsAcrossLaunchesInTheSecretStore() {
        let secrets = FakeSecretStore()
        let first = SavedCodes(secrets: secrets)
        first.save(SavedCode(name: "Ana", code: "ana-secret"))
        #expect(SavedCodes(secrets: secrets).codes.map(\.code) == ["ana-secret"])
    }

    @Test func removingTheLastCodeDeletesTheItem() {
        let secrets = FakeSecretStore()
        let saved = SavedCodes(secrets: secrets)
        let code = SavedCode(name: "Ana", code: "ana-secret")
        saved.save(code)
        saved.remove(id: code.id)
        #expect(saved.codes.isEmpty)
        #expect(secrets.items.isEmpty)
    }

    @Test func aFailedWriteIsFlaggedAndKeptForThisLaunch() {
        let secrets = FakeSecretStore()
        secrets.failWrites = true
        let saved = SavedCodes(secrets: secrets)
        saved.save(SavedCode(name: "Ana", code: "ana-secret"))
        #expect(saved.saveFailed)
        #expect(saved.codes.count == 1)
        #expect(SavedCodes(secrets: secrets).codes.isEmpty)
        secrets.failWrites = false
        saved.save(SavedCode(name: "Ben", code: "ben-secret"))
        #expect(!saved.saveFailed)
    }

    @Test func aFailedReadBlocksWritesSoTheStoredListIsNeverOverwritten() {
        let secrets = FakeSecretStore()
        SavedCodes(secrets: secrets).save(SavedCode(name: "Ana", code: "ana-secret"))
        let stored = secrets.items["savedCodes"]

        secrets.failReads = true
        let saved = SavedCodes(secrets: secrets)
        #expect(saved.loadFailed)
        saved.save(SavedCode(name: "Ben", code: "ben-secret"))
        saved.remove(id: UUID())
        #expect(saved.codes.isEmpty)
        #expect(secrets.items["savedCodes"] == stored, "the stored codes are untouched")

        secrets.failReads = false
        saved.reload()
        #expect(!saved.loadFailed)
        #expect(saved.codes.map(\.name) == ["Ana"])
    }

    @Test func aSaveRetriesTheLoadFirst() {
        let secrets = FakeSecretStore()
        SavedCodes(secrets: secrets).save(SavedCode(name: "Ana", code: "ana-secret"))
        secrets.failReads = true
        let saved = SavedCodes(secrets: secrets)
        secrets.failReads = false
        saved.save(SavedCode(name: "Ben", code: "ben-secret"))
        #expect(saved.codes.map(\.name) == ["Ana", "Ben"], "the earlier codes are kept")
    }

    @Test func anUnreadableItemReadsAsEmpty() {
        let secrets = FakeSecretStore()
        secrets.items["savedCodes"] = "not json"
        #expect(SavedCodes(secrets: secrets).codes.isEmpty)
    }
}
