import Croc
import Foundation

/// croc's default relays, from the engine. A relay setting that is blank or
/// equal to one of these is not custom, so the engine uses the public relay pool.
public enum RelayDefaults {
    public static var address: String { CrocmobileDefaultRelayAddress() }
    public static var address6: String { CrocmobileDefaultRelayAddress6() }
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
    public var overwrite = false
    public var noCompress = false
    public var zipFolder = false
    public var gitIgnore = false
    /// Substring patterns excluded from sends (croc --exclude semantics).
    public var exclude: [String] = []
    /// Both-sides confirm (croc --ask). Sender prompt is bridged via the
    /// stdin pipe; respond(accept:) answers it.
    public var ask = false
    public init() {}
}

public enum TransferEvent: Sendable {
    case codeReady(String)
    case connected
    case fileList(FileList)
    case progress(TransferProgress)
    case text(String)
    case done(Summary)
    case failed(EngineFailure)
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

public struct FileList: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public let name: String
        public let size: Int64
    }
    public let files: [Entry]
    public let emptyFolders: Int
    public let totalSize: Int64
}

public struct TransferProgress: Codable, Sendable {
    public let currentFile: Int
    public let totalFiles: Int
    public let fileName: String
    public let fileSent: Int64
    public let fileSize: Int64
    public let bytesFinished: Int64
    public let totalSize: Int64
    public let step: String
}

public struct Summary: Codable, Sendable {
    public let success: Bool
    public let files: Int
    public let totalSize: Int64
}
