import AppIntents
import Foundation

/// Why a Shortcuts action could not finish; the text is what Shortcuts shows.
enum TransferIntentError: Error, CustomLocalizedStringResourceConvertible {
    case busy
    case nothingToSend
    case notACodeOrLink
    case cancelled
    /// The words are already localized (`TransferFailure.text`).
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .busy: "CrocApp is already sending or receiving. Wait for it to finish."
        case .nothingToSend: "There is nothing to send."
        case .notACodeOrLink: "That is not a croc code or a CrocApp link."
        case .cancelled: "Cancelled."
        // A runtime string is not a literal, so it adds no catalog key.
        case .failed(let message): LocalizedStringResource(String.LocalizationValue(message))
        }
    }
}

extension TransferController {
    /// Frees the controller for a Shortcuts action. A finished transfer keeps
    /// its result on screen until someone taps Done, which nobody does on a
    /// phone running a shortcut, so it is cleared here; one still in flight
    /// refuses the action.
    func claimForIntent() throws {
        switch phase {
        case .idle: return
        case .done, .failed, .stored: reset()
        default: throw TransferIntentError.busy
        }
    }

    /// Looks at the controller every 100 ms until `check` yields a value, or
    /// returns nil once the action is cancelled. Polling, not observation: it
    /// ends on cancellation at once, and what it reads outlives the moment
    /// it changed.
    func wait<T>(for check: () -> T?) async -> T? {
        while !Task.isCancelled {
            if let value = check() { return value }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    /// The code of a send just started, once croc has one.
    func awaitCode() async throws -> String {
        let outcome = await wait { () -> Result<String, TransferIntentError>? in
            if let code = currentCode { return .success(code) }
            if case .failed(let failure) = phase { return .failure(.failed(failure.text)) }
            return nil
        }
        return try settle(outcome)
    }

    /// A cancelled action also stops the transfer it started.
    private func settle<T>(_ outcome: Result<T, TransferIntentError>?) throws -> T {
        guard let outcome else {
            cancel()
            throw TransferIntentError.cancelled
        }
        return try outcome.get()
    }

    /// The end of a receive just started: its received text, or a failure.
    func awaitReceive() async throws -> String? {
        let outcome = await wait { () -> Result<String?, TransferIntentError>? in
            switch phase {
            case .done(_, let text): .success(text)
            case .failed(let failure): .failure(.failed(failure.text))
            default: nil
            }
        }
        return try settle(outcome)
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
