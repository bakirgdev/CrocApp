import Testing

@testable import CrocApp

@MainActor @Suite struct SpotlightPurgeTests {
    private struct Failure: Error {}

    @Test func theIndexIsEmptiedUntilOneDeleteSucceedsAndNeverAgainAfter() async {
        let storage = MemorySettingsStorage()
        var calls = 0

        await SpotlightPurge.runOnce(storage: storage) {
            calls += 1
            throw Failure()
        }
        await SpotlightPurge.runOnce(storage: storage) { calls += 1 }
        await SpotlightPurge.runOnce(storage: storage) { calls += 1 }

        #expect(calls == 2, "a failure is retried, a success is final")
    }
}
