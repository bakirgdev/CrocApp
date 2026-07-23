import Foundation

public struct EngineOptions: Sendable {
    public var relayAddress = "croc.schollz.com:9009"
    public var relayAddress6 = "croc6.schollz.com:9009"
    public var relayPassword = "pass123"
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
    case failed(String)
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
