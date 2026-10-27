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

    /// A throwaway staging root with one staged item in a slot, for the delete
    /// guards. Never the real root.
    private func makeRoot() throws -> (root: URL, slot: URL, file: URL) {
        let root = URL.temporaryDirectory.appending(
            path: "SendStagingRoot-\(UUID().uuidString)", directoryHint: .isDirectory)
        let slot = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
        let file = slot.appending(path: "a.txt", directoryHint: .notDirectory)
        try Data("x".utf8).write(to: file)
        return (root, slot, file)
    }

    @Test func discardUnderARootRemovesTheSlot() throws {
        let made = try makeRoot()
        defer { try? FileManager.default.removeItem(at: made.root) }

        SendStaging.discard(made.file, under: made.root)

        #expect(!FileManager.default.fileExists(atPath: made.slot.path))
        #expect(FileManager.default.fileExists(atPath: made.root.path), "the root stays")
    }

    @Test func discardRefusesASymlinkedSlotAndSparesItsTarget() throws {
        let made = try makeRoot()
        let outside = URL.temporaryDirectory.appending(
            path: "SendStagingOutside-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let keep = outside.appending(path: "keep.txt", directoryHint: .notDirectory)
        try Data("keep".utf8).write(to: keep)
        let link = made.root.appending(path: "link", directoryHint: .notDirectory)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        defer {
            try? FileManager.default.removeItem(at: made.root)
            try? FileManager.default.removeItem(at: outside)
        }

        let through = link.appending(path: "keep.txt", directoryHint: .notDirectory)
        #expect(SendStaging.slotFolder(for: through, under: made.root) == nil)
        SendStaging.discard(through, under: made.root)

        #expect(FileManager.default.fileExists(atPath: keep.path), "the link's target survives")
        #expect(FileManager.default.fileExists(atPath: outside.path))
        #expect(FileManager.default.fileExists(atPath: link.path), "the link itself is left too")
    }

    @Test func discardRefusesAPathOutsideTheRoot() throws {
        let made = try makeRoot()
        let source = try makeSource(named: "report.pdf")
        defer {
            try? FileManager.default.removeItem(at: made.root)
            try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
        }

        SendStaging.discard(source, under: made.root)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: made.file.path))
    }

    @Test func discardRefusesTheRootAndABareSlot() throws {
        let made = try makeRoot()
        defer { try? FileManager.default.removeItem(at: made.root) }

        SendStaging.discard(made.root, under: made.root)
        SendStaging.discard(made.slot, under: made.root)

        #expect(FileManager.default.fileExists(atPath: made.file.path))
        #expect(SendStaging.slotFolder(for: made.root, under: made.root) == nil)
        #expect(SendStaging.slotFolder(for: made.slot, under: made.root) == nil)
    }

    @Test func dotDotCannotClimbOutOfTheRoot() throws {
        let made = try makeRoot()
        let source = try makeSource(named: "report.pdf")
        defer {
            try? FileManager.default.removeItem(at: made.root)
            try? FileManager.default.removeItem(at: source.deletingLastPathComponent())
        }
        let sneaky = made.slot.appending(
            path: "../../\(source.deletingLastPathComponent().lastPathComponent)/report.pdf")

        SendStaging.discard(sneaky, under: made.root)

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

@Suite(.serialized) struct SendLoadingTests {
    private func stagedPayload(named name: String) throws -> (SendPayload, URL) {
        let folder = URL.temporaryDirectory.appending(
            path: "SendLoadingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appending(path: name, directoryHint: .notDirectory)
        try Data("x".utf8).write(to: source)
        let staged = try SendStaging.stage(copying: source)
        return (.file(staged), staged)
    }

    @Test func loadsEveryItemAndCountsFailures() async throws {
        let loaded = await SendLoading.load([1, 2, 3]) { (item: Int) -> SendPayload? in
            switch item {
            case 1: .text("one")
            case 2: nil
            default: throw CocoaError(.fileReadUnknown)
            }
        }
        #expect(loaded?.payloads.count == 1)
        #expect(loaded?.failures == 2)
    }

    @Test func cancellingDiscardsWhatWasStaged() async throws {
        let (payload, staged) = try stagedPayload(named: "IMG_1.HEIC")
        let (started, signal) = AsyncStream<Void>.makeStream()
        let task = Task {
            await SendLoading.load([1, 2]) { (item: Int) -> SendPayload? in
                if item == 1 { return payload }
                signal.yield()
                try await Task.sleep(for: .seconds(60))
                return nil
            }
        }
        var iterator = started.makeAsyncIterator()
        await iterator.next()
        #expect(FileManager.default.fileExists(atPath: staged.path), "staged before the cancel")

        task.cancel()
        let loaded = await task.value

        #expect(loaded == nil)
        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
    }
}

@Suite struct SendReadinessTests {
    private func readiness(
        asLink: Bool = false, files: Bool = true, text: Bool = false, filesMode: Bool = true,
        serverOK: Bool = true, code: String = "", loading: Bool = false
    ) -> SendReadiness {
        SendReadiness(
            sendsAsLink: asLink, isFilesMode: filesMode, hasFiles: files, hasText: text,
            storedServerIsValid: serverOK, customCode: code, isLoadingPhotos: loading)
    }

    @Test func startsWithFilesOrText() {
        #expect(readiness().canStart)
        #expect(!readiness(files: false).canStart)
        #expect(readiness(files: false, text: true, filesMode: false).canStart)
        #expect(!readiness(files: false, text: true, filesMode: true).canStart)
    }

    @Test func waitsForPickedPhotosToFinishLoading() {
        #expect(!readiness(loading: true).canStart)
        #expect(!readiness(asLink: true, loading: true).canStart)
        #expect(readiness(loading: false).canStart)
    }

    @Test func aShortCustomCodeBlocksStarting() {
        #expect(!readiness(code: "ab").canStart)
        #expect(readiness(code: "").canStart)
        let enough = String(repeating: "a", count: EngineConstraints.minCodeLength)
        #expect(readiness(code: enough).canStart)
    }

    @Test func aLinkNeedsFilesAndAValidServer() {
        #expect(readiness(asLink: true).canStart)
        #expect(!readiness(asLink: true, serverOK: false).canStart)
        #expect(!readiness(asLink: true, files: false).canStart)
    }
}

@Suite struct FileSizeTextTests {
    @Test func anEmptyFileReadsAsZeroBytes() {
        #expect(FileRow.sizeText(0) == "0 bytes")
        #expect(FileRow.sizeText(1_000_000) == "1 MB")
    }
}
