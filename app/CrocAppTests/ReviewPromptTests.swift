import Testing

@testable import CrocApp

@Suite struct ReviewPromptTests {
    private func ask(_ count: Int, last: String = "", now: String = "1.2") -> Bool {
        ReviewPrompt.shouldAsk(
            successfulTransfers: count, lastPromptedVersion: last, currentVersion: now)
    }

    @Test func waitsForTheThirdSuccess() {
        #expect(!ask(0))
        #expect(!ask(2))
        #expect(ask(3))
        #expect(ask(10))
    }

    @Test func asksOncePerVersion() {
        #expect(!ask(5, last: "1.2"))
        #expect(ask(5, last: "1.1"), "a new version may ask again")
    }

    @Test func theCountAndVersionSurviveARelaunch() {
        let storage = MemorySettingsStorage()
        let first = AppSettings(storage: storage, secrets: FakeSecretStore())
        first.recordSuccessfulTransfer()
        first.recordSuccessfulTransfer()
        first.lastReviewPromptVersion = "1.2"
        let second = AppSettings(storage: storage, secrets: FakeSecretStore())
        #expect(second.successfulTransfers == 2)
        #expect(second.lastReviewPromptVersion == "1.2")
    }
}
