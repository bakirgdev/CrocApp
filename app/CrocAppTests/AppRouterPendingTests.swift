import Foundation
import Testing

@testable import CrocApp

/// Text staged for Send from outside the Send screen: it opens Send and
/// stages, and never navigates while a transfer is running.
@MainActor @Suite struct AppRouterPendingTests {
    @Test func textIsStagedAndSendOpens() {
        let router = AppRouter()
        router.openSend(text: "hello")
        #expect(router.pendingSendText == "hello")
        #expect(router.path == [.send])
    }

    @Test func stagedTextAccumulatesAndEmptyTextIsIgnored() {
        let router = AppRouter()
        router.openSend(text: "one")
        router.openSend(text: "")
        router.openSend(text: "two")
        #expect(router.pendingSendText == "one\ntwo")
    }

    @Test(arguments: [("", "new", "new"), ("typed", "new", "typed\nnew")])
    func appendingKeepsWhatIsThere(existing: String, new: String, expected: String) {
        #expect(AppRouter.appending(new, to: existing) == expected)
    }

    @Test func aBusyRouterStagesWithoutNavigating() {
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        let router = AppRouter()
        router.attach(controller: controller)
        #expect(
            controller.start(
                .sendFiles(urls: [URL(filePath: "/CrocAppTests.missing/notes.txt")], code: "")))
        router.openSend(text: "later")
        #expect(router.path.isEmpty)
        #expect(router.pendingSendText == "later")
    }
}
