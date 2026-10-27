import CoreTransferable
import Foundation
import OSLog
import UniformTypeIdentifiers

/// One thing handed to Send: dropped on it, pasted into it or picked in the
/// Photos picker. Import only; nothing here is exported.
///
/// Order is priority. A file URL wins over the image or movie content of the
/// same item, so a file copied in Finder or dragged from Files is sent as the
/// file itself, not as a copy of its bytes.
nonisolated enum SendPayload: Transferable {
    /// A file or folder at its own path, or a copy made in `SendStaging`.
    case file(URL)
    case text(String)

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(importing: { (url: URL) -> SendPayload in
            // A web address is text to send, not a file.
            url.isFileURL ? .file(url) : .text(url.absoluteString)
        })
        // The system deletes the file it hands over when the closure returns,
        // so the closure copies it somewhere that lasts.
        FileRepresentation(importedContentType: .image) { received in
            .file(try SendStaging.stage(copying: received.file, contentType: .image))
        }
        FileRepresentation(importedContentType: .movie) { received in
            .file(try SendStaging.stage(copying: received.file, contentType: .movie))
        }
        ProxyRepresentation(importing: { (text: String) -> SendPayload in .text(text) })
    }
}

extension SendPayload {
    /// What a paste can carry for Send.
    static let pasteTypes: [UTType] = [.fileURL, .url, .image, .movie, .text]

    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "send")

    /// Imports each pasted item once. An item that cannot be imported is logged
    /// and skipped, so one bad item never drops the rest.
    static func load(_ providers: [NSItemProvider]) async -> [SendPayload] {
        var payloads: [SendPayload] = []
        for provider in providers {
            do {
                payloads.append(try await load(provider))
            } catch {
                log.error("paste import failed: \(String(describing: error), privacy: .public)")
            }
        }
        return payloads
    }

    // `NSItemProvider` has no async form of `loadTransferable(type:)`.
    private static func load(_ provider: NSItemProvider) async throws -> SendPayload {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadTransferable(type: SendPayload.self) {
                continuation.resume(with: $0)
            }
        }
    }
}

/// What a batch of payloads adds to Send.
nonisolated struct SendIntake: Equatable {
    private(set) var files: [URL] = []
    private(set) var text: String?

    init(_ payloads: [SendPayload]) {
        var lines: [String] = []
        for payload in payloads {
            switch payload {
            case .file(let url): files.append(url)
            case .text(let string): lines.append(string)
            }
        }
        let joined = lines.joined(separator: "\n")
        text = joined.isEmpty ? nil : joined
    }

    var isEmpty: Bool { files.isEmpty && text == nil }

    /// The text box after adding `text`: it fills an empty box and goes on a new
    /// line after anything already typed, so a paste never replaces it.
    func text(appendedTo existing: String) -> String? {
        guard let text else { return nil }
        return existing.isEmpty ? text : existing + "\n" + text
    }
}

/// Brings a batch of picked items in as payloads, and owns what happens to the
/// staged copies when the batch is abandoned.
nonisolated enum SendLoading {
    struct Loaded {
        var payloads: [SendPayload]
        /// Items that could not be brought in.
        var failures: Int
    }

    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "send")

    /// Loads every item in order. If the surrounding task is cancelled (the
    /// screen went away, or the pick changed), everything staged so far is
    /// discarded and the result is nil: nobody is left to own those files.
    static func load<Item: Sendable>(
        _ items: [Item],
        using loadItem: @Sendable (Item) async throws -> SendPayload?
    ) async -> Loaded? {
        var loaded = Loaded(payloads: [], failures: 0)
        for item in items {
            if Task.isCancelled { break }
            do {
                if let payload = try await loadItem(item) {
                    loaded.payloads.append(payload)
                } else {
                    loaded.failures += 1
                }
            } catch is CancellationError {
                break
            } catch {
                log.error("photo load failed: \(String(describing: error), privacy: .public)")
                loaded.failures += 1
            }
        }
        guard !Task.isCancelled else {
            discard(loaded.payloads)
            return nil
        }
        return loaded
    }

    /// Deletes the staged copy behind each file payload. Files the user owns
    /// are left alone (`SendStaging.discard`).
    static func discard(_ payloads: [SendPayload]) {
        for case .file(let url) in payloads { SendStaging.discard(url) }
    }
}

/// Whether the Send button may be pressed. Pure, so the rules are tested
/// without the view.
struct SendReadiness {
    var sendsAsLink: Bool
    var isFilesMode: Bool
    var hasFiles: Bool
    var hasText: Bool
    var storedServerIsValid: Bool
    /// The custom code as typed, trimmed.
    var customCode: String
    var isLoadingPhotos: Bool

    var canStart: Bool {
        // Picked photos are still being copied in: starting now would send
        // without them.
        guard !isLoadingPhotos else { return false }
        if sendsAsLink { return hasFiles && storedServerIsValid }
        let codeOK = customCode.isEmpty || customCode.count >= EngineConstraints.minCodeLength
        return codeOK && (isFilesMode ? hasFiles : hasText)
    }
}
