import Foundation
import OSLog
import UniformTypeIdentifiers

/// Scratch space for what Send is handed as bytes rather than as a file the
/// user owns: photos and videos from the Photos picker, and images dropped or
/// pasted from another app. Each item gets its own folder, so the original file
/// name survives and two items with the same name never collide.
///
/// Nothing here outlives a launch. A staged file is deleted when its row is
/// removed or the Send screen goes away with no transfer running, and the whole
/// folder is swept the first time a Send screen appears in a launch. A running
/// transfer reads its files in place, so it is never swept from under croc.
nonisolated enum SendStaging {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "send")

    /// `ShareInbox` learned the same thing for the share extension: croc reads
    /// staged files during the transfer, so cleanup is by owner (row, screen,
    /// launch), never by timer.
    static var root: URL {
        URL.temporaryDirectory.appending(path: "SendStaging", directoryHint: .isDirectory)
    }

    /// Copies `file` into a fresh folder under `root` and returns the copy.
    /// `contentType` names the extension when `file` has none.
    static func stage(copying file: URL, contentType: UTType? = nil) throws -> URL {
        let name = fileName(for: file.lastPathComponent, contentType: contentType)
        let folder = try slot()
        let copy = folder.appending(path: name, directoryHint: .notDirectory)
        do {
            try FileManager.default.copyItem(at: file, to: copy)
        } catch {
            remove(folder)
            throw error
        }
        return copy
    }

    /// A name that is safe to create under a staging folder: one path
    /// component, never empty, with an extension when the type knows one.
    static func fileName(for proposed: String, contentType: UTType? = nil) -> String {
        var name = proposed.replacing("/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." {
            name = "Image"
        }
        if URL(filePath: name).pathExtension.isEmpty,
            let ext = contentType?.preferredFilenameExtension
        {
            name += ".\(ext)"
        }
        return name
    }

    /// True for a file `stage(copying:)` made.
    static func isStaged(_ url: URL) -> Bool {
        // Components, not a string prefix: a directory URL's path ends in "/".
        let root = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let path = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        return path.count > root.count && path.starts(with: root)
    }

    /// Deletes a staged file with its folder. Anything else is left alone, so
    /// a file the user picked is never removed.
    static func discard(_ url: URL) {
        guard isStaged(url) else { return }
        remove(url.deletingLastPathComponent())
    }

    /// Sweeps what an earlier launch left behind. Runs once per launch, from the
    /// first Send screen, which is before anything is staged in this one.
    static func purgeOnce() {
        _ = launchSweep
    }

    private static let launchSweep: Void = purge()

    /// Deletes everything staged. Only safe while no transfer is reading it.
    static func purge() {
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) else {
            return
        }
        remove(root)
    }

    private static func slot() throws -> URL {
        let slot = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
        return slot
    }

    /// Best effort: a leftover file costs disk space until the next launch, so
    /// a failure is logged and the app carries on.
    private static func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            log.error("staging cleanup failed: \(String(describing: error), privacy: .public)")
        }
    }
}
