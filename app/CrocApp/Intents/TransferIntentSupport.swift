import AppIntents
import Foundation
import Observation

/// Why a Shortcuts action could not finish; the text is what Shortcuts shows.
enum TransferIntentError: Error, CustomLocalizedStringResourceConvertible {
    case busy
    case nothingToSend
    case notACodeOrLink
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .busy: "CrocApp is already sending or receiving. Wait for it to finish."
        case .nothingToSend: "There is nothing to send."
        case .notACodeOrLink: "That is not a croc code or a CrocApp link."
        case .failed(let message): "\(message)"
        }
    }
}

extension TransferController {
    /// Suspends until `transform` yields a value for the current phase. The
    /// check and the observation registration happen in one main-actor turn,
    /// so no phase change can slip between them.
    func wait<T>(for transform: (Phase) -> T?) async -> T? {
        while !Task.isCancelled {
            if let value = transform(phase) { return value }
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = phase
                } onChange: {
                    continuation.resume()
                }
            }
        }
        return nil
    }

    /// The code of a send just started, once croc has one.
    func awaitCode() async throws -> String {
        let outcome = await wait { phase -> Result<String, TransferIntentError>? in
            switch phase {
            case .waiting(let code): .success(code)
            case .failed(let message): .failure(.failed(message))
            default: nil
            }
        }
        return try (outcome ?? .failure(.failed("Cancelled."))).get()
    }

    /// The end of a receive just started: its received text, or a failure.
    func awaitReceive() async throws -> String? {
        let outcome = await wait { phase -> Result<String?, TransferIntentError>? in
            switch phase {
            case .done(_, let text): .success(text)
            case .failed(let message): .failure(.failed(message))
            default: nil
            }
        }
        return try (outcome ?? .failure(.failed("Cancelled."))).get()
    }
}

/// Files a Shortcuts action hands over that have no usable file URL are
/// written here, and swept at the start of the next send. A send outlives its
/// action, so they cannot be deleted when the action returns.
enum IntentStaging {
    private static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "ShortcutsFiles", isDirectory: true)
    }

    static func sweep() {
        try? FileManager.default.removeItem(at: directory)
    }

    static func urls(for files: [IntentFile]) throws -> [URL] {
        try files.map { file in
            if let url = file.fileURL { return url }
            let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(file.filename)
            try file.data.write(to: url)
            return url
        }
    }

    static func textFile(_ text: String) throws -> URL {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Received text.txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// Finds what a receive wrote. croc keeps the sender's modification dates, so
/// the files that arrived are told apart by creation date: a Keep Both copy
/// ("name (1).ext") is new, while a Replace overwrites the file at its name.
enum ReceivedFileLocator {
    static func locate(names: [String], in folder: URL, since: Date) -> [URL] {
        names.compactMap { name in
            let wanted = folder.appendingPathComponent(name)
            let parent = wanted.deletingLastPathComponent()
            let stem = wanted.deletingPathExtension().lastPathComponent
            let suffix = wanted.pathExtension.isEmpty ? "" : "." + wanted.pathExtension
            let entries =
                (try? FileManager.default.contentsOfDirectory(
                    at: parent, includingPropertiesForKeys: [.creationDateKey])) ?? []
            let created = entries.filter {
                isCopy($0.lastPathComponent, stem: stem, suffix: suffix)
                    && ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate)
                        ?? .distantPast)
                        >= since
            }
            if let newest = created.max(by: { creation($0) < creation($1) }) { return newest }
            return FileManager.default.fileExists(atPath: wanted.path) ? wanted : nil
        }
    }

    /// `name.ext` itself or its numbered Keep Both copy `name (n).ext`.
    static func isCopy(_ file: String, stem: String, suffix: String) -> Bool {
        guard file.hasPrefix(stem), file.hasSuffix(suffix),
            file.count >= stem.count + suffix.count
        else { return false }
        let middle = String(file.dropFirst(stem.count).dropLast(suffix.count))
        return middle.isEmpty || middle.wholeMatch(of: /\ \(\d+\)/) != nil
    }

    private static func creation(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
