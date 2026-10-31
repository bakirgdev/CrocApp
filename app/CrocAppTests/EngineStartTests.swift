import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// What a request hands the engine, built from the settings with no engine
/// involved.
@MainActor @Suite struct EngineStartTests {
    private let settings: AppSettings
    private let file = URL(filePath: "/CrocAppTests.missing/notes.txt")
    private let folder = URL(filePath: "/CrocAppTests.missing/inbox")

    init() {
        settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
    }

    @Test func aFileSendCarriesEverySendSetting() {
        settings.relayAddress = "relay.example:9009"
        settings.relayPassword = "relay-pass"
        settings.noCompress = true
        settings.zipFolder = true
        settings.useGitIgnore = true
        settings.excludePatterns = "node_modules\n  .DS_Store  \n"
        settings.bothSidesConfirm = true
        settings.throttleUpload = " 500k "
        settings.noMultiplexing = true
        settings.internalDNS = true
        settings.excludePaths = "src/secret.txt\n  build/out.bin  \n"
        settings.socks5Proxy = " socks5://user:secret@proxy.example:1080 "
        settings.httpProxy = " http://proxy.example:8080 "
        let start = EngineStart(
            .sendFiles(urls: [file], code: "custom-code-word"), settings: settings,
            disableLocal: true)
        guard case .send(let paths, let text, let o) = start else {
            Issue.record("built \(start), not a send")
            return
        }
        #expect(paths == [file.path])
        #expect(text == nil)
        #expect(o.customCode == "custom-code-word")
        #expect(o.relayAddress == "relay.example:9009")
        #expect(o.relayPassword == "relay-pass")
        #expect(o.noCompress)
        #expect(o.zipFolder)
        #expect(o.gitIgnore)
        #expect(o.exclude == ["node_modules", ".DS_Store"])
        #expect(o.ask)
        #expect(o.throttleUpload == "500k")
        #expect(o.noMultiplexing)
        #expect(o.internalDNS)
        #expect(o.excludePaths == ["src/secret.txt", "build/out.bin"])
        #expect(o.socks5Proxy == "socks5://user:secret@proxy.example:1080")
        #expect(o.httpProxy == "http://proxy.example:8080")
        #expect(o.disableLocal)
        #expect(o.workDir == FileManager.default.temporaryDirectory.path)
        #expect(o.outDir.isEmpty)
        #expect(!o.autoAccept)
        #expect(!start.autoAccept)
    }

    @Test func skipLocalNetworkIsTheUsersOrTheHarnesss() {
        func skips(setting: Bool, harness: Bool) -> Bool {
            settings.disableLocal = setting
            guard
                case .send(_, _, let o) = EngineStart(
                    .sendText(text: "hi", code: ""), settings: settings, disableLocal: harness)
            else { return false }
            return o.disableLocal
        }
        #expect(!skips(setting: false, harness: false))
        #expect(skips(setting: true, harness: false))
        #expect(skips(setting: false, harness: true))
    }

    @Test func aTextSendCarriesSingleConnection() {
        settings.noMultiplexing = true
        let start = EngineStart(.sendText(text: "hi", code: ""), settings: settings)
        guard case .send(_, _, let o) = start else {
            Issue.record("built \(start), not a send")
            return
        }
        #expect(o.noMultiplexing)
    }

    @Test func aTextSendLeavesTheFileOptionsOff() {
        settings.zipFolder = true
        settings.useGitIgnore = true
        settings.excludePatterns = "node_modules"
        settings.excludePaths = "a.txt"
        let start = EngineStart(.sendText(text: "hello", code: ""), settings: settings)
        guard case .send(let paths, let text, let o) = start else {
            Issue.record("built \(start), not a send")
            return
        }
        #expect(paths.isEmpty)
        #expect(text == "hello")
        #expect(o.customCode.isEmpty)
        #expect(!o.zipFolder)
        #expect(!o.gitIgnore)
        #expect(o.exclude.isEmpty)
        #expect(o.excludePaths.isEmpty)
        #expect(!o.disableLocal, "only a harness run turns the LAN route off")
    }

    @Test func aReceiveCarriesTheFolderSenderIPAndPolicy() {
        settings.peerIP = " 192.0.2.7:9009 "
        settings.noMultiplexing = true
        settings.whenFileExists = .replace
        settings.onlyLocal = true
        let start = EngineStart(
            .receive(code: "wiry-alpha-bravo", folder: folder, folderIsScoped: true),
            settings: settings)
        guard case .receive(let code, let o) = start else {
            Issue.record("built \(start), not a receive")
            return
        }
        #expect(code == "wiry-alpha-bravo")
        #expect(o.outDir == folder.path)
        #expect(o.peerIP == "192.0.2.7:9009")
        #expect(o.whenFileExists == .replace)
        #expect(o.onlyLocal)
        #expect(
            !o.noMultiplexing, "a receiver on one connection hangs against a multiplexing sender")
        #expect(o.customCode.isEmpty)
    }

    /// Ask forces croc's prompt, which engine auto-accept would answer with a
    /// decline, so confirmation wins.
    @Test(arguments: [(false, false, false), (true, false, true), (true, true, false)])
    func receiveAutoAcceptYieldsToConfirmation(
        autoAccept: Bool, bothSidesConfirm: Bool, expected: Bool
    ) {
        settings.autoAccept = autoAccept
        settings.bothSidesConfirm = bothSidesConfirm
        let start = EngineStart(
            .receive(code: "wiry-alpha-bravo", folder: folder, folderIsScoped: false),
            settings: settings)
        guard case .receive(_, let o) = start else {
            Issue.record("built \(start), not a receive")
            return
        }
        #expect(o.autoAccept == expected)
        #expect(o.ask == bothSidesConfirm)
        #expect(start.autoAccept == expected)
    }

    @Test func aStoredSendGoesToTheTrimmedServer() {
        settings.storedServer = " https://store.example "
        settings.socks5Proxy = " socks5://proxy.example:1080 "
        settings.autoAccept = true
        let start = EngineStart(
            .storedSend(urls: [file], downloads: 3, lifetimeSeconds: 3600), settings: settings)
        guard case .storeSend(let paths, let o) = start else {
            Issue.record("built \(start), not a stored send")
            return
        }
        #expect(paths == [file.path])
        #expect(o.server == "https://store.example")
        #expect(o.downloads == 3)
        #expect(o.lifetimeSeconds == 3600)
        #expect(o.proxy == ProxySettings(socks5: "socks5://proxy.example:1080"))
        #expect(!start.autoAccept)
    }

    @Test func aStoredReceiveCarriesTheLinkFolderAndProxy() throws {
        settings.httpProxy = "http://proxy.example:8080"
        settings.autoAccept = true
        let link = try #require(URL(string: "https://store.example/s/up1#v1.key"))
        let start = EngineStart(
            .storedReceive(link: link, folder: folder, folderIsScoped: false), settings: settings)
        guard case .storeReceive(let linkText, let outDir, let proxy) = start else {
            Issue.record("built \(start), not a stored receive")
            return
        }
        #expect(linkText == "https://store.example/s/up1#v1.key")
        #expect(outDir == folder.path)
        #expect(proxy == ProxySettings(http: "http://proxy.example:8080"))
        #expect(!start.autoAccept, "auto-accept never applies to a stored link")
    }

    @Test func multicastReachesTheEngineWhenSet() {
        settings.multicastAddress = " 239.255.0.7 "
        guard
            case .send(_, _, let set) = EngineStart(
                .sendText(text: "x", code: ""), settings: settings)
        else {
            Issue.record("not a send")
            return
        }
        #expect(set.multicastAddress == "239.255.0.7")

        settings.multicastAddress = ""
        guard
            case .send(_, _, let blank) = EngineStart(
                .sendText(text: "x", code: ""), settings: settings)
        else {
            Issue.record("not a send")
            return
        }
        #expect(blank.multicastAddress == EngineOptions().multicastAddress)
    }
}
