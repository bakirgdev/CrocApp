import Testing

@testable import CrocApp

@MainActor @Suite struct SpotlightPurgeTests {
    private struct Failure: Error {}

    @Test func theIndexIsEmptiedAtEveryLaunchEvenAfterAFailure() async {
        var calls = 0

        await SpotlightPurge.run {
            calls += 1
            throw Failure()
        }
        await SpotlightPurge.run { calls += 1 }
        await SpotlightPurge.run { calls += 1 }

        #expect(calls == 3)
    }
}
