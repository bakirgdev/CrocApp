import Foundation
import Testing
import UniformTypeIdentifiers

@testable import CrocApp

/// Photos and dropped images land in `SendStaging` under their own names, and
/// only what staging made is ever deleted.
@Suite(.serialized) struct SendStagingTests {
    /// A file outside the staging folder, like one the user picked.
    private func makeSource(named name: String, contents: String = "bytes") throws -> URL {
        let folder = URL.temporaryDirectory.appending(
            path: "SendStagingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test func stagingKeepsTheNameAndCopiesTheBytes() throws {
        let source = try makeSource(named: "IMG_0042.HEIC", contents: "pixels")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        let staged = try SendStaging.stage(copying: source)
        defer { SendStaging.discard(staged) }

        #expect(staged.lastPathComponent == "IMG_0042.HEIC")
        #expect(SendStaging.isStaged(staged))
        #expect(try String(contentsOf: staged, encoding: .utf8) == "pixels")
        #expect(FileManager.default.fileExists(atPath: source.path), "the original stays")
    }

    @Test func sameNameTwiceDoesNotCollide() throws {
        let source = try makeSource(named: "IMG_0001.JPG")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        let first = try SendStaging.stage(copying: source)
        let second = try SendStaging.stage(copying: source)
        defer {
            SendStaging.discard(first)
            SendStaging.discard(second)
        }

        #expect(first != second)
        #expect(first.lastPathComponent == second.lastPathComponent)
    }

    @Test func discardRemovesTheStagedFileAndItsFolder() throws {
        let source = try makeSource(named: "clip.mov")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let staged = try SendStaging.stage(copying: source)

        SendStaging.discard(staged)

        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
    }

    @Test func discardLeavesAFileStagingDidNotMake() throws {
        let source = try makeSource(named: "report.pdf")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

        #expect(!SendStaging.isStaged(source))
        SendStaging.discard(source)

        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func purgeRemovesEverythingStaged() throws {
        let source = try makeSource(named: "a.png")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let staged = try SendStaging.stage(copying: source)

        SendStaging.purge()

        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: SendStaging.root.path))
    }

    @Test(arguments: [
        ("IMG_0001.HEIC", UTType.image, "IMG_0001.HEIC"),
        ("IMG_0001", UTType.jpeg, "IMG_0001.jpeg"),
        ("", UTType.png, "Image.png"),
        ("..", UTType.png, "Image.png"),
        ("a/b.png", UTType.png, "a-b.png"),
        ("  clip  ", UTType.quickTimeMovie, "clip.mov"),
    ])
    func namesAreSafeAndKeepAnExtension(proposed: String, type: UTType, expected: String) {
        #expect(SendStaging.fileName(for: proposed, contentType: type) == expected)
    }
}

@Suite struct SendIntakeTests {
    private let file = URL(filePath: "/tmp/a.txt")
    private let other = URL(filePath: "/tmp/b.txt")

    @Test func filesAndTextAreSeparated() {
        let intake = SendIntake([.file(file), .text("one"), .file(other), .text("two")])
        #expect(intake.files == [file, other])
        #expect(intake.text == "one\ntwo")
    }

    @Test func nothingIsEmpty() {
        #expect(SendIntake([]).isEmpty)
        #expect(SendIntake([.text("")]).isEmpty)
        #expect(!SendIntake([.file(file)]).isEmpty)
    }

    @Test func textFillsAnEmptyBoxAndNeverReplacesTyping() {
        let intake = SendIntake([.text("pasted")])
        #expect(intake.text(appendedTo: "") == "pasted")
        #expect(intake.text(appendedTo: "typed") == "typed\npasted")
        #expect(SendIntake([.file(file)]).text(appendedTo: "typed") == nil)
    }
}
