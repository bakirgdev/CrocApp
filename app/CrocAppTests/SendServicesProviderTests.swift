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

    @Test func textOverTheLimitIsRefusedAndTheLimitItselfIsAccepted() {
        pasteboard.clearContents()
        pasteboard.setString(
            String(repeating: "a", count: SendServicesProvider.maxTextBytes), forType: .string)
        #expect(provider.stageText(from: pasteboard))
        let atLimit = router.pendingSendText

        pasteboard.clearContents()
        pasteboard.setString(
            String(repeating: "a", count: SendServicesProvider.maxTextBytes + 1), forType: .string)
        #expect(!provider.stageText(from: pasteboard))
        #expect(router.pendingSendText == atLimit, "the refused text is not staged")
    }

    @Test func theLimitCountsBytesNotCharacters() {
        // "é" is two UTF-8 bytes: half the limit in characters is over it.
        pasteboard.clearContents()
        pasteboard.setString(
            String(repeating: "é", count: SendServicesProvider.maxTextBytes / 2 + 1),
            forType: .string)
        #expect(!provider.stageText(from: pasteboard))
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

/// The `NSServices` entries are the system's only link to the provider: a
/// renamed method or a plist that drifted would leave the menu item doing
/// nothing, with no build error.
@MainActor @Suite struct SendServicesRegistrationTests {
    nonisolated private static let plists = [
        "CrocApp-macOS-Info.plist", "CrocApp-Direct-Info.plist",
    ]

    private func services(in name: String) throws -> [[String: Any]] {
        // app/CrocAppTests/<this file> -> app/Config/<plist>
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Config/\(name)")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let info = try #require(plist as? [String: Any])
        return try #require(info["NSServices"] as? [[String: Any]])
    }

    @Test(arguments: plists) func eachMessageNamesAMethodOfTheProvider(plist: String) throws {
        let entries = try services(in: plist)
        let messages = entries.compactMap { $0["NSMessage"] as? String }
        #expect(Set(messages) == ["sendFiles", "sendText"])
        for message in messages {
            // AppKit derives the selector `<message>:userData:error:`.
            let selector = Selector("\(message):userData:error:")
            #expect(
                SendServicesProvider.instancesRespond(to: selector),
                "\(plist): no @objc method for NSMessage \(message)")
        }
    }

    @Test(arguments: plists) func theMenuItemAndPortMatchTheApp(plist: String) throws {
        for entry in try services(in: plist) {
            let item = entry["NSMenuItem"] as? [String: String]
            #expect(item?["default"] == "Send with CrocApp")
            #expect(entry["NSPortName"] as? String == "CrocApp")
        }
    }
}
#endif
