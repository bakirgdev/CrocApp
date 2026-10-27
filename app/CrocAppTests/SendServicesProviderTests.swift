#if os(macOS)
import AppKit
import Foundation
import Testing

@testable import CrocApp

/// The Services menu entry "Send with CrocApp": what it stages from the
/// service's pasteboard, and that it never starts a transfer. Each test uses a
/// private pasteboard, so the user's clipboard is never read or written.
@MainActor @Suite struct SendServicesProviderTests {
    private let router = AppRouter()
    private let provider: SendServicesProvider
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("CrocAppTests.\(UUID())"))

    init() {
        provider = SendServicesProvider(router: router)
    }

    @Test func selectedFilesAreStagedAndSendOpens() {
        let first = URL(filePath: "/CrocAppTests.missing/a.txt")
        let second = URL(filePath: "/CrocAppTests.missing/folder", directoryHint: .isDirectory)
        pasteboard.clearContents()
        pasteboard.writeObjects([first as NSURL, second as NSURL])
        #expect(provider.stageFiles(from: pasteboard))
        #expect(router.pendingSendURLs == [first, second])
        #expect(router.path == [.send])
    }

    @Test func selectedTextIsStagedAndSendOpens() {
        pasteboard.clearContents()
        pasteboard.setString("some selected words", forType: .string)
        #expect(provider.stageText(from: pasteboard))
        #expect(router.pendingSendText == "some selected words")
        #expect(router.path == [.send])
    }

    @Test func aWebAddressIsNotAFileToSend() {
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(string: "https://example.com/a.txt")! as NSURL])
        #expect(!provider.stageFiles(from: pasteboard))
        #expect(router.pendingSendURLs.isEmpty)
        #expect(router.path.isEmpty)
    }

    @Test func nothingOrBlankTextStagesNothing() {
        pasteboard.clearContents()
        #expect(!provider.stageFiles(from: pasteboard))
        #expect(!provider.stageText(from: pasteboard))
        pasteboard.setString(" \n\t ", forType: .string)
        #expect(!provider.stageText(from: pasteboard))
        #expect(router.pendingSendText == nil)
        #expect(router.path.isEmpty)
    }

    @Test func aRunningTransferKeepsItsScreenAndTheSelectionWaits() {
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        router.attach(controller: controller)
        #expect(
            controller.start(
                .sendFiles(urls: [URL(filePath: "/CrocAppTests.missing/notes.txt")], code: "")))
        let phase = controller.phase

        pasteboard.clearContents()
        pasteboard.setString("later", forType: .string)
        #expect(provider.stageText(from: pasteboard))
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(filePath: "/CrocAppTests.missing/b.txt") as NSURL])
        #expect(provider.stageFiles(from: pasteboard))

        #expect(router.path.isEmpty, "the router does not navigate mid-transfer")
        #expect(router.pendingSendText == "later")
        #expect(router.pendingSendURLs.count == 1)
        #expect(controller.phase == phase, "a service never starts or changes a transfer")
    }

    @Test func stagingNeverStartsATransfer() {
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        router.attach(controller: controller)
        pasteboard.clearContents()
        pasteboard.setString("words", forType: .string)
        #expect(provider.stageText(from: pasteboard))
        #expect(!controller.isActive)
    }
}
#endif
