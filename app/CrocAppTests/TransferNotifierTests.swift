import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// CrocKit's wire types have no public memberwise initializers; they decode.
func testSummary(success: Bool) -> Summary {
    try! JSONDecoder().decode(
        Summary.self, from: Data(#"{"success":\#(success),"files":1,"totalSize":10}"#.utf8))
}

@MainActor
private final class FakeNotificationCenter: NotificationPosting {
    private(set) var posted: [TransferNotice] = []
    private(set) var permissionRequests = 0
    private(set) var removals = 0

    func requestAuthorization() async { permissionRequests += 1 }
    func post(_ notice: TransferNotice) { posted.append(notice) }
    func removeDelivered() { removals += 1 }
}

@MainActor @Suite struct TransferNotifierTests {
    private let center = FakeNotificationCenter()
    private let settings = AppSettings(
        storage: MemorySettingsStorage(), secrets: FakeSecretStore())
    private let controller: TransferController

    private static let list = try! JSONDecoder().decode(
        FileList.self,
        from: Data(
            #"{"files":[{"name":"secret-plans.pdf","size":10}],"emptyFolders":0,"totalSize":10}"#
                .utf8))
    private static let done = TransferController.Phase.done(
        testSummary(success: true), receivedText: nil)

    init() {
        controller = TransferController(
            settings: settings, vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
    }

    private func notifier(appActive: Bool = false) -> TransferNotifier {
        TransferNotifier(
            controller: controller, settings: settings, center: center,
            isAppActive: { appActive })
    }

    @Test func switchesDefaultToOnAndFileNamesOff() {
        #expect(settings.notificationsEnabled)
        #expect(!settings.notificationsShowFileNames)
    }

    @Test func finishedFailedAndIncomingNotifyOthersDoNot() {
        func title(_ phase: TransferController.Phase) -> String? {
            TransferNotifier.notice(
                for: phase, direction: .receive, offeredNames: [], showNames: false)?.title
        }
        #expect(title(Self.done) == "Transfer complete")
        #expect(
            title(.done(testSummary(success: false), receivedText: nil))
                == "Transfer finished with errors")
        #expect(
            title(.failed(TransferFailure(title: "T", detail: nil, remedy: nil)))
                == "Transfer failed")
        #expect(title(.incoming(Self.list, conflicts: [], blocked: [])) != nil)
        #expect(title(.confirmSend) != nil)
        for quiet in [
            TransferController.Phase.idle, .starting, .waiting(code: "wiry-alpha-bravo"),
            .connecting, .transferring,
            .failed(TransferFailure(title: "T", detail: nil, remedy: nil, endedByUser: true)),
        ] {
            #expect(title(quiet) == nil)
        }
    }

    @Test func fileNamesAppearOnlyWithTheSwitch() {
        let phase = TransferController.Phase.incoming(Self.list, conflicts: [], blocked: [])
        let off = TransferNotifier.notice(
            for: phase, direction: .receive, offeredNames: [], showNames: false)
        let on = TransferNotifier.notice(
            for: phase, direction: .receive, offeredNames: [], showNames: true)
        #expect(off?.body == nil)
        #expect(on?.body == "secret-plans.pdf")
    }

    @Test func aNameTheAppBlocksIsNeverShown() {
        let notice = TransferNotifier.notice(
            for: .done(testSummary(success: true), receivedText: nil), direction: .receive,
            offeredNames: ["invoice\u{202E}fdp.exe"], showNames: true)
        #expect(notice?.body == nil)
    }

    @Test func aCodePhraseNeverReachesANotice() {
        let code = "wiry-alpha-bravo"
        let notice = TransferNotifier.notice(
            for: .waiting(code: code), direction: .send, offeredNames: [code], showNames: true)
        #expect(notice == nil)
    }

    @Test func postsOnlyWhileTheAppIsNotActive() {
        let background = notifier(appActive: false)
        background.handle(phase: Self.done, percent: nil, enabled: true)
        #expect(center.posted.count == 1)

        let foreground = notifier(appActive: true)
        foreground.handle(phase: Self.done, percent: nil, enabled: true)
        #expect(center.posted.count == 1)
    }

    @Test func aSecondUpdateOfTheSameNoticePostsOnce() {
        let n = notifier()
        let a = TransferController.Phase.incoming(Self.list, conflicts: [], blocked: [])
        let b = TransferController.Phase.incoming(Self.list, conflicts: ["x"], blocked: [])
        n.handle(phase: a, percent: nil, enabled: true)
        n.handle(phase: b, percent: nil, enabled: true)
        #expect(center.posted.count == 1)
    }

    @Test func switchOffPostsNothingAndLeavingAnAnswerPhaseClearsTheNotice() {
        let n = notifier()
        n.handle(phase: Self.done, percent: nil, enabled: false)
        #expect(center.posted.isEmpty)
        n.handle(phase: .confirmSend, percent: nil, enabled: true)
        n.handle(phase: .transferring, percent: 5, enabled: true)
        #expect(center.removals == 1)
    }

    @Test func permissionIsAskedWhenTheFirstTransferStartsOrTheSwitchTurnsOn() async {
        let n = notifier()
        n.handle(phase: .idle, percent: nil, enabled: true)
        #expect(center.permissionRequests == 0)
        n.handle(phase: .starting, percent: nil, enabled: true)
        await Task.yield()
        #expect(center.permissionRequests == 1)

        let off = notifier()
        off.handle(phase: .idle, percent: nil, enabled: false)
        off.handle(phase: .idle, percent: nil, enabled: true)
        await Task.yield()
        #expect(center.permissionRequests == 2)
    }

    @Test func dockBadgeShowsPercentWhileMovingAndOneWhileAsked() {
        #expect(TransferNotifier.dockBadge(for: .transferring, percent: 42) == "42%")
        #expect(TransferNotifier.dockBadge(for: .transferring, percent: nil) == nil)
        #expect(TransferNotifier.dockBadge(for: .confirmSend, percent: nil) == "1")
        #expect(
            TransferNotifier.dockBadge(
                for: .incoming(Self.list, conflicts: [], blocked: []), percent: nil) == "1")
        #expect(TransferNotifier.dockBadge(for: .idle, percent: nil) == nil)
        #expect(TransferNotifier.dockBadge(for: Self.done, percent: nil) == nil)
    }
}
