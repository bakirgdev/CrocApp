import Foundation
import Testing

@testable import CrocApp

/// The tab selection, the drafts it keeps, and the entry points that fill them
/// (design/principles.md → Platform adaptation). Each test starts on History,
/// not on Send, the default, so a move to Send is a visible change.
@MainActor @Suite struct AppRouterTests {
    private let router = AppRouter()

    init() {
        router.selection = .history
    }

    private func busyController() -> TransferController {
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        router.attach(controller: controller)
        #expect(
            controller.start(
                .sendFiles(urls: [URL(filePath: "/CrocAppTests.missing/notes.txt")], code: "")))
        return controller
    }

    // MARK: - Drafts survive a selection change

    @Test func whatIsStagedAndTypedSurvivesAChangeOfTab() {
        let file = URL(filePath: "/CrocAppTests.missing/a.txt")
        router.sendDraft.add([file])
        router.sendDraft.append(text: "typed")
        router.sendDraft.customCode = "wiry-alpha-bravo"
        router.sendDraft.sendAsLink = true
        router.receiveDraft.code = "mild-alpha-bravo"

        for screen in AppRouter.Screen.allCases + [.send] {
            router.selection = screen
        }

        #expect(router.sendDraft.pickedURLs == [file])
        #expect(router.sendDraft.text == "typed")
        #expect(router.sendDraft.customCode == "wiry-alpha-bravo")
        #expect(router.sendDraft.sendAsLink)
        #expect(router.receiveDraft.code == "mild-alpha-bravo")
    }

    // MARK: - Entry points land on their tab

    @Test func everyEntryPointLandsOnItsTab() throws {
        router.openSend(with: [URL(filePath: "/CrocAppTests.missing/a.txt")])
        #expect(router.selection == .send)

        router.openReceive()
        #expect(router.selection == .receive)

        router.selection = .history
        router.open(try #require(TransferLink.parse("wiry-alpha-bravo")))
        #expect(router.selection == .receive)
        #expect(router.receiveDraft.code == "wiry-alpha-bravo")

        router.selection = .history
        router.openSend(text: "hello")
        #expect(router.selection == .send)
        #expect(router.sendDraft.text == "hello")

        router.selection = .send
        router.openHistory()
        #expect(router.selection == .history)
    }

    @Test func menuCommandsNavigate() {
        router.showSettings(advanced: true)
        #expect(router.selection == .settings)
        #expect(router.settingsPath == [.advanced])

        router.showSettings()
        #expect(router.settingsPath.isEmpty)

        router.showHistory()
        #expect(router.selection == .history)

        router.showHowItWorks()
        #expect(router.showsHowItWorks)
        #expect(router.selection == .history, "a sheet over the open tab, not a tab")
    }

    @Test func aTransfersDirectionNamesItsTab() {
        #expect(AppRouter.Screen(direction: .send) == .send)
        #expect(AppRouter.Screen(direction: .receive) == .receive)
    }

    // MARK: - Mid-transfer

    @Test func nothingNavigatesWhileATransferIsActiveButDraftsFill() throws {
        let controller = busyController()
        #expect(router.isBusy)

        let file = URL(filePath: "/CrocAppTests.missing/b.txt")
        router.openSend(with: [file])
        router.openSend(text: "hello")
        router.open(try #require(TransferLink.parse("wiry-alpha-bravo")))
        router.openHistory()

        #expect(router.selection == .history, "the user stays where they are")
        #expect(router.sendDraft.pickedURLs == [file])
        #expect(router.sendDraft.text == "hello")
        #expect(router.receiveDraft.code == "wiry-alpha-bravo", "kept for the next Receive")
        controller.cancel()
    }
}

@MainActor @Suite struct SendDraftTests {
    private let draft = SendDraft()

    @Test func addingFilesDeduplicatesAndShowsTheFilesMode() {
        let file = URL(filePath: "/CrocAppTests.missing/a.txt")
        draft.mode = .text
        draft.add([file, file])
        draft.add([file])
        #expect(draft.pickedURLs == [file])
        #expect(draft.mode == .files)
    }

    @Test func addingNothingChangesNothing() {
        draft.mode = .text
        draft.add([])
        #expect(draft.mode == .text)
    }

    @Test func stagedTextAccumulatesAndEmptyTextIsIgnored() {
        draft.append(text: "one")
        draft.append(text: "")
        draft.append(text: "two")
        #expect(draft.text == "one\ntwo")
        #expect(draft.mode == .text)
    }

    @Test func filesWinOverTextAndTextAppendsToWhatIsTyped() {
        let file = URL(filePath: "/CrocAppTests.missing/a.txt")
        #expect(draft.stage([.file(file), .text("a.txt")]))
        #expect(draft.pickedURLs == [file])
        #expect(draft.text.isEmpty)

        draft.text = "typed"
        #expect(draft.stage([.text("pasted")]))
        #expect(draft.text == "typed\npasted")
        #expect(draft.mode == .text)
    }

    @Test func aFileAlreadyStagedIsNotAddedAgain() {
        let file = URL(filePath: "/CrocAppTests.missing/a.txt")
        #expect(draft.stage([.file(file)]))
        #expect(!draft.stage([.file(file)]))
        #expect(draft.pickedURLs == [file])
    }
}

@MainActor @Suite struct ReceiveDraftTests {
    private let draft = ReceiveDraft()

    @Test func aCodeFillsTheFieldAndClearsALink() throws {
        draft.storedLink = URL(string: "https://example.com/x")
        draft.apply(try #require(TransferLink.parse("wiry-alpha-bravo")))
        #expect(draft.code == "wiry-alpha-bravo")
        #expect(draft.storedLink == nil)
    }

    @Test func aStoredLinkReplacesTheCode() {
        let url = URL(string: "https://example.com/x")!
        draft.code = "wiry-alpha-bravo"
        draft.apply(.stored(url))
        #expect(draft.storedLink == url)
        #expect(draft.code.isEmpty)
    }
}
