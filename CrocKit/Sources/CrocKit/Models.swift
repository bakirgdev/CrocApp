import Croc
import Foundation

/// croc's default relays, from the engine. A relay setting that is blank or
/// equal to one of these is not custom, so the engine uses the public relay pool.
public enum RelayDefaults {
    public static var address: String { CrocmobileDefaultRelayAddress() }
    public static var address6: String { CrocmobileDefaultRelayAddress6() }
}

/// A setting whose value the engine checks. `validate(_:)` runs the check a
/// transfer start runs, so a settings form shows an error exactly when the
/// transfer would refuse the value, and never tells the two apart.
public enum EngineSetting: Sendable, CaseIterable {
    case socks5Proxy
    case httpProxy
    /// Send only: `EngineOptions.throttleUpload`.
    case throttleUpload
    case multicastAddress
    /// Receive only: `EngineOptions.peerIP`.
    case peerIP
    /// `StoredSendOptions.server`.
    case storeServer

    /// Throws an `EngineFailure` with code `.invalidSetting` when the engine
    /// refuses `value`. Blank is valid for every setting except `storeServer`,
    /// which needs an origin. A proxy failure never quotes the value, which can
    /// carry credentials. A pure, fast call: no transfer state, any thread.
    public func validate(_ value: String) throws {
        var error: NSError?
        guard CrocmobileValidateSetting(engineName, value, &error) else {
            throw EngineFailure(payload: error?.localizedDescription)
        }
    }

    /// The name `ValidateSetting` in `crocmobile/network.go` takes.
    private var engineName: String {
        switch self {
        case .socks5Proxy: CrocmobileSettingSocks5Proxy
        case .httpProxy: CrocmobileSettingHTTPProxy
        case .throttleUpload: CrocmobileSettingThrottleUpload
        case .multicastAddress: CrocmobileSettingMulticastAddress
        case .peerIP: CrocmobileSettingPeerIP
        case .storeServer: CrocmobileSettingStoreServer
        }
    }
}

/// What a receive does with an incoming file whose name already exists.
/// Raw values mirror `PolicyKeepBoth` and `PolicyReplace` in
/// `crocmobile/crocmobile.go`.
public enum FilePolicy: String, Sendable, CaseIterable {
    /// The existing file stays; croc saves the new one as "name (1).ext". A
    /// partly received file is not resumed. In a zipped folder, members that
    /// already exist are skipped.
    case keepBoth
    /// The new file overwrites the existing one; croc resumes a partly
    /// received file.
    case replace
}

/// The proxies a connection goes through. Either may carry credentials in a
/// URL (`socks5://user:secret@host:1080`), so the description never shows them.
/// Blank means none; SOCKS5 wins when both are set.
public struct ProxySettings: Sendable, Equatable {
    /// `host:port` or a `socks5://` / `socks5h://` URL.
    public var socks5 = ""
    /// `host:port` or an `http://` / `https://` URL.
    public var http = ""
    public init(socks5: String = "", http: String = "") {
        self.socks5 = socks5
        self.http = http
    }
}

extension ProxySettings: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "ProxySettings(socks5: \(socks5.isEmpty ? "none" : "set"), http: \(http.isEmpty ? "none" : "set"))"
    }
    public var debugDescription: String { description }
}

public struct EngineOptions: Sendable {
    /// Blank relay fields mean croc's defaults (see `RelayDefaults`).
    public var relayAddress = ""
    public var relayAddress6 = ""
    public var relayPassword = ""
    public var customCode = ""
    public var outDir = ""
    public var workDir = ""
    public var disableLocal = false
    public var onlyLocal = false
    public var autoAccept = false
    /// Receive: applies as is under `autoAccept`; otherwise
    /// `respond(accept:policy:)` replaces it.
    public var whenFileExists = FilePolicy.keepBoth
    public var noCompress = false
    public var zipFolder = false
    public var gitIgnore = false
    /// Substring patterns excluded from sends (croc --exclude semantics).
    public var exclude: [String] = []
    /// Both-sides confirm (croc --ask). Sender prompt is bridged via the
    /// stdin pipe; respond(accept:policy:) answers it.
    public var ask = false

    // Advanced options. The defaults are croc's own (`EngineOptionsDefaultsTests`
    // checks them against the engine).

    /// Send only: bytes per second, digits with an optional `k`, `m` or `g`
    /// (`"500k"`). Blank means no limit.
    public var throttleUpload = ""
    /// IPv4 multicast group for finding peers on the local network. Both sides
    /// must use the same one.
    public var multicastAddress = CrocmobileDefaultMulticastAddress
    /// Receive only: the sender's `ip:port` (IPv6 in brackets). Connects
    /// straight to it and turns the public relay pool off.
    public var peerIP = ""
    /// May carry credentials; see `ProxySettings`.
    public var socks5Proxy = ""
    /// May carry credentials; see `ProxySettings`.
    public var httpProxy = ""
    public init() {}
}

extension EngineOptions: CustomStringConvertible, CustomDebugStringConvertible {
    /// Names the options without their values: the relay password and the proxies are secrets.
    public var description: String {
        "EngineOptions(relay: \(relayAddress.isEmpty ? "default" : "custom"), "
            + "proxy: \(socks5Proxy.isEmpty && httpProxy.isEmpty ? "none" : "set"))"
    }
    public var debugDescription: String { description }
}

public enum TransferEvent: Sendable {
    case codeReady(String)
    case connected
    case fileList(FileList)
    case progress(TransferProgress)
    case text(String)
    /// A stored upload finished: the receipt arrives just before `.done`.
    case stored(StoredReceipt)
    case done(Summary)
    case failed(EngineFailure)
}

/// A stored-transfer upload: the file contents are encrypted on this device and
/// kept on `origin` until `expiresAt` or until the download count runs out.
public struct StoredReceipt: Codable, Sendable, Equatable {
    public let id: String
    public let origin: String
    /// Secret: proves the right to revoke. Never log or display it.
    public let uploadToken: String
    /// Secret: the fragment after `#v1.` is the decryption key.
    public let link: String
    public let expiresAt: Date
    public let downloads: Int

    public init(
        id: String, origin: String, uploadToken: String, link: String, expiresAt: Date,
        downloads: Int
    ) {
        self.id = id
        self.origin = origin
        self.uploadToken = uploadToken
        self.link = link
        self.expiresAt = expiresAt
        self.downloads = downloads
    }

    private enum CodingKeys: String, CodingKey {
        case id, origin, uploadToken, link, expiresAt, downloads
    }

    /// The engine writes `expiresAt` as RFC 3339 in UTC, whole seconds.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension StoredReceipt: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "StoredReceipt(id: \(id), origin: \(origin), secrets hidden)" }
    public var debugDescription: String { description }
}

/// What a stored upload asks of the server. `server` must be an `https` origin
/// (`http` only on loopback). The server may cap `lifetimeSeconds` and refuses
/// a `downloads` above its limit with `EngineFailure.Code.storeLimit`.
public struct StoredSendOptions: Sendable {
    public var server = "https://getcroc.com"
    /// 1 to 100.
    public var downloads = 1
    public var lifetimeSeconds = 86_400
    public var proxy = ProxySettings()
    public init() {}
}

/// Why a transfer failed, classified by the engine next to croc. Show copy for
/// `code`; `message` is croc's own text, for logs only, and changes between
/// croc releases.
public struct EngineFailure: Error, Equatable, Sendable {
    /// Mirrors the codes in `crocmobile/errors.go`. An unknown code decodes as
    /// `.other`, so a newer engine never breaks an older decoder.
    public enum Code: String, Sendable, CaseIterable {
        case peerVersion, relayUnreachable, noPublicRelay, declined, refused
        case roomFull, badPassword, wrongCode, cancelled, connectionLost, other
        /// Stored transfers: the server's size, file-count, download, quota or rate limit.
        case storeLimit
        /// Stored transfers: the server no longer has it (expired, revoked, used up).
        case storeExpired
        /// An Advanced option (proxy, speed limit, multicast address, sender IP) failed the engine's check.
        case invalidSetting
        /// A start while another transfer still holds the engine. `CrocEngine`
        /// throws `CrocEngineError.transferActive` for it.
        case transferActive
        /// A cancelled transfer never returned; until the app relaunches, every
        /// start fails with this code.
        case engineStuck
        /// This receiver joined the room before the sender (croc's local-probe race).
        case joinedEarly
    }

    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }

    private struct Payload: Decodable {
        let code: String
        let message: String
    }

    /// Decodes the engine's `{"code","message"}` payload. Anything else
    /// becomes `.other` carrying the raw text.
    init(payload: String?) {
        guard let payload else {
            self.init(code: .other, message: "unknown error")
            return
        }
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: Data(payload.utf8)) else {
            self.init(code: .other, message: payload)
            return
        }
        self.init(code: Code(rawValue: decoded.code) ?? .other, message: decoded.message)
    }
}

public struct FileList: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let name: String
        public let size: Int64
    }
    public let files: [Entry]
    public let emptyFolders: Int
    public let totalSize: Int64
}

public struct TransferProgress: Codable, Sendable, Equatable {
    public let currentFile: Int
    public let totalFiles: Int
    public let fileName: String
    public let fileSent: Int64
    public let fileSize: Int64
    public let bytesFinished: Int64
    public let totalSize: Int64
    public let step: String
}

public struct Summary: Codable, Sendable, Equatable {
    public let success: Bool
    public let files: Int
    public let totalSize: Int64
}
