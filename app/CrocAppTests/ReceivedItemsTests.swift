import Foundation
import Testing

@testable import CrocApp

/// What the receive result screen lists: the top-level items a receive wrote,
/// found from the offered names in a real folder.
@Suite final class ReceivedItemsTests {
    private let folder = FileManager.default.temporaryDirectory.appending(
        path: "CrocAppTests.\(UUID().uuidString)")
    private let now = Date.now

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit {
        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            Issue.record("could not remove \(folder.path): \(error)")
        }
    }

    // MARK: - keepBothOriginal

    @Test(arguments: [
        ("a (2).txt", "a.txt"), ("a (12).txt", "a.txt"), ("README (2)", "README"),
        ("my file (3).png", "my file.png"),
    ])
    func namesTheFileACopyWasMadeFrom(copy: String, original: String) {
        #expect(ReceivedFileLocator.keepBothOriginal(of: copy) == original)
    }

    @Test(arguments: ["a.txt", "a (x).txt", "a(1).txt", "(1).txt", "README"])
    func aPlainNameIsNoCopy(name: String) {
        #expect(ReceivedFileLocator.keepBothOriginal(of: name) == nil)
    }

    // MARK: - locate

    @Test func aFileResolvesToItsNameWhenNoCopyIsNew() throws {
        try write("a.txt", bytes: 5, created: now)

        let items = ReceivedItems.locate(
            names: ["a.txt"], in: folder, since: now.addingTimeInterval(-10))

        #expect(items.map(\.url.lastPathComponent) == ["a.txt"])
        #expect(items.first?.size == 5)
        #expect(items.first?.isFolder == false)
    }

    @Test func aKeepBothCopyWinsOverTheFileItCopied() throws {
        try write("a.txt", bytes: 1, created: now.addingTimeInterval(-3600))
        try write("a (1).txt", bytes: 2, created: now.addingTimeInterval(-5))

        let items = ReceivedItems.locate(
            names: ["a.txt"], in: folder, since: now.addingTimeInterval(-60))

        #expect(items.map(\.url.lastPathComponent) == ["a (1).txt"])
        #expect(items.first?.size == 2)
    }

    @Test func theNewestCopyWins() throws {
        try write("a.txt", bytes: 1, created: now.addingTimeInterval(-3600))
        try write("a (1).txt", bytes: 1, created: now.addingTimeInterval(-50))
        try write("a (2).txt", bytes: 1, created: now.addingTimeInterval(-5))

        let items = ReceivedItems.locate(
            names: ["a.txt"], in: folder, since: now.addingTimeInterval(-60))

        #expect(items.map(\.url.lastPathComponent) == ["a (2).txt"])
    }

    @Test func aCopyFromBeforeTheReceiveIsNotThisReceives() throws {
        try write("a.txt", bytes: 1, created: now.addingTimeInterval(-3600))
        try write("a (1).txt", bytes: 1, created: now.addingTimeInterval(-1800))

        let items = ReceivedItems.locate(
            names: ["a.txt"], in: folder, since: now.addingTimeInterval(-60))

        #expect(items.map(\.url.lastPathComponent) == ["a.txt"], "Replace overwrote a.txt")
    }

    @Test func aFolderIsListedOnceForEveryNameInsideIt() throws {
        let inner = folder.appending(path: "photos/2026", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try write("photos/2026/x.jpg", bytes: 3, created: now)
        try write("photos/y.jpg", bytes: 3, created: now)
        try write("z.txt", bytes: 4, created: now)

        let items = ReceivedItems.locate(
            names: ["photos/2026/x.jpg", "photos/y.jpg", "z.txt"], in: folder,
            since: now.addingTimeInterval(-10))

        #expect(items.map(\.url.lastPathComponent) == ["photos", "z.txt"])
        #expect(items.map(\.isFolder) == [true, false])
        #expect(items.first?.size == nil)
    }

    @Test func aFileOfferedUnderItsOwnNumberedNameIsNotACopy() throws {
        try write("a.txt", bytes: 1, created: now)
        try write("a (1).txt", bytes: 2, created: now)

        let items = ReceivedItems.locate(
            names: ["a.txt", "a (1).txt"], in: folder, since: now.addingTimeInterval(-10))

        #expect(items.map(\.url.lastPathComponent) == ["a.txt", "a (1).txt"])
        #expect(items.map(\.size) == [1, 2])
    }

    @Test func anItemThatIsNotThereIsLeftOut() throws {
        try write("a.txt", bytes: 1, created: now)

        let items = ReceivedItems.locate(
            names: ["gone.txt", "a.txt", "gone/dir.txt"], in: folder,
            since: now.addingTimeInterval(-10))

        #expect(items.map(\.url.lastPathComponent) == ["a.txt"])
    }

    @Test func anUnreadableFolderHasNoItems() {
        let missing = folder.appending(path: "missing")
        #expect(ReceivedItems.locate(names: ["a.txt"], in: missing, since: now).isEmpty)
    }

    // MARK: - Helpers

    /// Writes `bytes` bytes to `path` under the folder and sets its creation
    /// date, which is what tells a Keep Both copy from an older file.
    private func write(_ path: String, bytes: Int, created: Date) throws {
        let url = folder.appending(path: path)
        try Data(count: bytes).write(to: url)
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
    }
}
