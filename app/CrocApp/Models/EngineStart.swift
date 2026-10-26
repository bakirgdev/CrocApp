import CrocKit
import Foundation

/// The engine call a `TransferRequest` makes, with its options built from the
/// settings at the moment it starts. Building it touches no engine, so tests
/// check every option without one.
enum EngineStart {
    case send(paths: [String], text: String?, options: EngineOptions)
    case receive(code: String, options: EngineOptions)
    case storeSend(paths: [String], options: StoredSendOptions)
    case storeReceive(link: String, outDir: String, proxy: ProxySettings)

    /// `disableLocal` is the harness's `--disable-local`, not a user setting.
    init(_ request: TransferRequest, settings: AppSettings, disableLocal: Bool = false) {
        switch request {
        case .sendFiles(let urls, let code):
            var options = Self.baseOptions(settings, disableLocal: disableLocal)
            options.customCode = code
            options.workDir = FileManager.default.temporaryDirectory.path
            options.zipFolder = settings.zipFolder
            options.gitIgnore = settings.useGitIgnore
            options.exclude = settings.excludeList
            self = .send(paths: urls.map(\.path), text: nil, options: options)
        case .sendText(let text, let code):
            var options = Self.baseOptions(settings, disableLocal: disableLocal)
            options.customCode = code
            options.workDir = FileManager.default.temporaryDirectory.path
            self = .send(paths: [], text: text, options: options)
        case .receive(let code, let folder, _):
            var options = Self.baseOptions(settings, disableLocal: disableLocal)
            options.outDir = folder.path
            options.peerIP = settings.peerIP.trimmingCharacters(in: .whitespacesAndNewlines)
            // Auto-accept uses the setting; otherwise the incoming sheet's answer
            // replaces it.
            options.whenFileExists = settings.whenFileExists
            // Ask forces croc's receiver prompt even under NoPrompt, and the
            // engine's AutoAccept path closes the prompt pipe (EOF = decline),
            // so Ask wins when both are on.
            options.autoAccept = settings.autoAccept && !settings.bothSidesConfirm
            self = .receive(code: code, options: options)
        case .storedSend(let urls, let downloads, let lifetimeSeconds):
            var options = StoredSendOptions()
            options.server = Self.storedServer(settings)
            options.downloads = downloads
            options.lifetimeSeconds = lifetimeSeconds
            options.proxy = Self.proxies(settings)
            self = .storeSend(paths: urls.map(\.path), options: options)
        case .storedReceive(let link, let folder, _):
            self = .storeReceive(
                link: link.absoluteString, outDir: folder.path, proxy: Self.proxies(settings))
        }
    }

    /// Engine auto-accept is on: croc proceeds without the incoming prompt.
    var autoAccept: Bool {
        if case .receive(_, let options) = self { return options.autoAccept }
        return false
    }

    func run(on engine: any TransferEngine) async throws -> EngineTransfer {
        switch self {
        case .send(let paths, let text, let options):
            try await engine.startSend(paths: paths, text: text, options: options)
        case .receive(let code, let options):
            try await engine.startReceive(code: code, options: options)
        case .storeSend(let paths, let options):
            try await engine.startStoreSend(paths: paths, options: options)
        case .storeReceive(let link, let outDir, let proxy):
            try await engine.startStoreReceive(link: link, outDir: outDir, proxy: proxy)
        }
    }

    /// The Advanced proxies, trimmed. Credentials may be inside: pass them on,
    /// never log or describe them.
    static func proxies(_ settings: AppSettings) -> ProxySettings {
        ProxySettings(
            socks5: settings.socks5Proxy.trimmingCharacters(in: .whitespacesAndNewlines),
            http: settings.httpProxy.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func storedServer(_ settings: AppSettings) -> String {
        settings.storedServer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func baseOptions(_ settings: AppSettings, disableLocal: Bool) -> EngineOptions {
        var o = EngineOptions()
        o.relayAddress = settings.relayAddress
        o.relayAddress6 = settings.relayAddress6
        o.relayPassword = settings.relayPassword
        o.onlyLocal = settings.onlyLocal
        o.disableLocal = disableLocal
        o.noCompress = settings.noCompress
        o.ask = settings.bothSidesConfirm
        o.throttleUpload = settings.throttleUpload.trimmingCharacters(in: .whitespacesAndNewlines)
        let proxies = proxies(settings)
        o.socks5Proxy = proxies.socks5
        o.httpProxy = proxies.http
        let multicast = settings.multicastAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !multicast.isEmpty { o.multicastAddress = multicast }
        return o
    }
}
