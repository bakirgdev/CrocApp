import Foundation
import Testing

@testable import CrocApp

@Suite struct ShareHandoffBatchNameTests {
    @Test func generatedNameIsValid() {
        #expect(ShareHandoff.isValidBatchName(ShareHandoff.makeBatchName()))
    }

    @Test func generatedNamesDiffer() {
        #expect(ShareHandoff.makeBatchName() != ShareHandoff.makeBatchName())
    }

    @Test func acceptsALowercaseUUID() {
        #expect(ShareHandoff.isValidBatchName("batch-" + UUID().uuidString.lowercased()))
    }

    @Test(arguments: [
        "", "batch-", "batch-not-a-uuid", "../x", "a/b", "..", ".", "/etc",
        "batch-00000000-0000-0000-0000-000000000000/..",
        "batch-00000000-0000-0000-0000-000000000000x",
        // UUID(uuidString:) accepts a trailing NUL; the length check must not.
        "batch-00000000-0000-0000-0000-000000000000\0",
        "batch-00000000-0000-0000-0000-000000000000\u{301}",
        "batch- 00000000-0000-0000-0000-000000000000",
        "00000000-0000-0000-0000-000000000000",
        "Batch-00000000-0000-0000-0000-000000000000",
    ])
    func rejectsOtherNames(name: String) {
        #expect(!ShareHandoff.isValidBatchName(name))
    }
}

/// The extension's decisions, which live in `ShareHandoff` because tests
/// cannot import the extension target.
@Suite struct ShareStagingRulesTests {
    @Test func aFreeNameStaysAsIs() {
        #expect(ShareHandoff.stagedName(for: "report.pdf") { _ in false } == "report.pdf")
    }

    @Test func aTakenNameGetsTheNextFreePrefix() {
        let taken: Set = ["a.txt", "2-a.txt"]
        #expect(ShareHandoff.stagedName(for: "a.txt") { taken.contains($0) } == "3-a.txt")
    }

    @Test func theManifestNameIsNeverUsedForAFile() {
        let name = ShareHandoff.stagedName(for: ShareHandoff.manifestName) { _ in false }
        #expect(name == "2-" + ShareHandoff.manifestName)
    }

    @Test(arguments: [".hidden", "../escape.txt", "invoice\u{202E}fdp.exe", "line\u{2028}break"])
    func anUnusableNameBecomesSharedFile(name: String) {
        #expect(ShareHandoff.stagedName(for: name) { _ in false } == "shared-file")
        #expect(ShareHandoff.stagedName(for: name) { $0 == "shared-file" } == "2-shared-file")
    }

    @Test func filesTakePrecedenceOverText() {
        #expect(ShareHandoff.batchText(fileCount: 1, texts: ["hello"]) == nil)
        #expect(
            ShareHandoff.batchText(fileCount: 0, texts: ["hello", " ", "https://a.b"])
                == "hello\nhttps://a.b")
        #expect(ShareHandoff.batchText(fileCount: 0, texts: [" "]) == nil)
    }

    @Test func theSpaceCheckMeasuresOnlyACrossVolumeCopy() {
        var measured = false
        #expect(
            ShareHandoff.copyFits(sameVolume: true, free: 0) {
                measured = true
                return 1
            })
        #expect(!measured, "a same-volume copy clones, so the folder is never walked")
        #expect(ShareHandoff.copyFits(sameVolume: false, free: 10) { 10 })
        #expect(!ShareHandoff.copyFits(sameVolume: false, free: 10) { 11 })
        #expect(
            ShareHandoff.copyFits(sameVolume: false, free: nil) { 11 }, "unknown space never blocks"
        )
    }
}

/// The inbox is in the App Group container, so `ShareInbox` treats what it
/// finds there as untrusted. Each test works in a temp directory standing in
/// for the container's inbox.
@MainActor
@Suite struct ShareInboxTests {
    /// `root` holds `inbox` plus anything a hostile name could reach from it.
    private struct Sandbox {
        let root: URL
        let inbox: URL
    }

    private func makeSandbox() throws -> Sandbox {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ShareInboxTests-" + UUID().uuidString, isDirectory: true)
        let inbox = root.appendingPathComponent(ShareHandoff.inboxDirName, isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return Sandbox(root: root, inbox: inbox)
    }

    /// A batch as the extension leaves it: its files, then its manifest.
    /// `age` back-dates its creation, which orders batches and drives the purge.
    @discardableResult
    private func stageBatch(
        _ files: [String], present: [String]? = nil, text: String? = nil,
        named name: String = ShareHandoff.makeBatchName(), age: TimeInterval = 0, in inbox: URL
    ) throws -> URL {
        let dir = inbox.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for file in present ?? files { try touch(dir.appendingPathComponent(file)) }
        let data = try JSONEncoder().encode(ShareHandoff.Manifest(files: files, text: text))
        try data.write(to: ShareHandoff.manifestURL(inBatch: dir))
        try backdate(dir, by: age)
        return dir
    }

    private func backdate(_ url: URL, by age: TimeInterval) throws {
        try FileManager.default.setAttributes(
            [.creationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
    }

    private func touch(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// An inbox whose purge sees every batch as older than the grace period.
    private func lateInbox() -> ShareInbox {
        let inbox = ShareInbox()
        inbox.now = { .now.addingTimeInterval(2 * ShareInbox.stagingGrace) }
        return inbox
    }

    @Test func stagesTheFilesOfAValidBatch() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let dir = try stageBatch(
            ["a.txt", "b.txt", "missing.txt"], present: ["a.txt", "b.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.batch == dir.lastPathComponent)
        #expect(inbox.staged.map(\.lastPathComponent) == ["a.txt", "b.txt"])
        #expect(inbox.staged.allSatisfy { $0.deletingLastPathComponent().path == dir.path })
    }

    @Test func anUnsafeNameDropsOnlyThatName() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let unsafe = [
            "../escape.txt", "invoice\u{202E}fdp.exe", "line\u{2028}break.txt", "a\\b.txt",
            "/abs.txt",
        ]
        // The names that can exist on disk do, so only the name check can be
        // what drops them.
        try touch(box.inbox.appendingPathComponent("escape.txt"))
        try stageBatch(
            ["ok.txt"] + unsafe,
            present: ["ok.txt", "invoice\u{202E}fdp.exe", "line\u{2028}break.txt"],
            in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.map(\.lastPathComponent) == ["ok.txt"])
    }

    @Test(arguments: [
        "x", "batch-", "batch-not-a-uuid", "Batch-00000000-0000-0000-0000-000000000000",
    ])
    func aDirectoryWithAnotherNameIsNeverOffered(name: String) throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        try stageBatch(["f.txt"], named: name, in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.batch == nil)
        #expect(inbox.staged.isEmpty)
    }

    /// A batch-shaped symlink is not a directory the extension made, so it is
    /// neither offered nor followed when the purge deletes.
    @Test func aBatchNamedSymlinkIsNeitherOfferedNorFollowed() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let outside = try stageBatch(["f.txt"], in: box.root)
        try FileManager.default.createSymbolicLink(
            at: box.inbox.appendingPathComponent(ShareHandoff.makeBatchName()),
            withDestinationURL: outside)

        let inbox = lateInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.isEmpty)
        #expect(exists(outside.appendingPathComponent("f.txt")))
    }

    @Test func aSecondShareWaitsForTheFirst() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let first = try stageBatch(["a.txt"], age: 20, in: box.inbox)
        let second = try stageBatch(["b.txt"], age: 10, in: box.inbox)
        let inbox = ShareInbox()

        inbox.refresh(in: box.inbox)
        #expect(inbox.batch == first.lastPathComponent, "oldest first")

        inbox.consume(first.lastPathComponent)
        inbox.refresh(in: box.inbox)
        #expect(inbox.batch == second.lastPathComponent)
        #expect(inbox.staged.map(\.lastPathComponent) == ["b.txt"])
        #expect(exists(first.appendingPathComponent("a.txt")), "the first send still reads it")
    }

    @Test func aConsumedBatchStaysUntilItsSendFinishes() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let dir = try stageBatch(["a.txt"], in: box.inbox)
        let inbox = lateInbox()
        inbox.refresh(in: box.inbox)

        inbox.consume(dir.lastPathComponent)
        inbox.refresh(in: box.inbox)
        #expect(inbox.batch == nil, "consumed: not offered again")
        #expect(exists(dir.appendingPathComponent("a.txt")), "kept past the grace for a retry")

        inbox.sendFinished()
        #expect(!exists(dir))
        inbox.sendFinished()  // nothing left to delete
    }

    @Test func discardDeletesTheBatchAtOnce() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let dir = try stageBatch(["a.txt"], in: box.inbox)
        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        inbox.discard(dir.lastPathComponent)

        #expect(!exists(dir))
    }

    @Test func purgeRemovesABatchThatNeverGotItsManifest() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let live = try stageBatch(["a.txt"], in: box.inbox)
        let stale = box.inbox.appendingPathComponent(ShareHandoff.makeBatchName())
        try touch(stale.appendingPathComponent("b.txt"))

        lateInbox().refresh(in: box.inbox)

        #expect(exists(live))
        #expect(!exists(stale))
    }

    @Test func purgeLeavesABatchThatMayStillBeFilling() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let filling = box.inbox.appendingPathComponent(ShareHandoff.makeBatchName())
        try touch(filling.appendingPathComponent("part.bin"))

        ShareInbox().refresh(in: box.inbox)

        #expect(exists(filling))
    }

    @Test func purgeDoesNotKeepAnInvalidBatchName() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let named = try stageBatch(["f.txt"], named: "x", in: box.inbox)

        lateInbox().refresh(in: box.inbox)

        #expect(!exists(named))
    }
}

@MainActor
@Suite struct ShareInboxTextTests {
    private func makeInbox() throws -> URL {
        let inbox = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ShareInboxTextTests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    private func stageBatch(files: [String] = [], text: String?, in inbox: URL) throws {
        let dir = inbox.appendingPathComponent(ShareHandoff.makeBatchName(), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for file in files { try Data("x".utf8).write(to: dir.appendingPathComponent(file)) }
        let data = try JSONEncoder().encode(ShareHandoff.Manifest(files: files, text: text))
        try data.write(to: ShareHandoff.manifestURL(inBatch: dir))
    }

    /// The text a fresh inbox holding one batch with `text` offers.
    private func offered(_ text: String) throws -> String? {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        try stageBatch(text: text, in: inbox)
        let model = ShareInbox()
        model.refresh(in: inbox)
        return model.text
    }

    @Test func readsSharedText() throws {
        #expect(try offered("https://example.com/a\nhello") == "https://example.com/a\nhello")
    }

    @Test func filesTakePrecedenceOverText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        try stageBatch(files: ["a.txt"], text: "hello", in: inbox)

        let model = ShareInbox()
        model.refresh(in: inbox)

        #expect(model.staged.count == 1)
        #expect(model.text == nil)
    }

    @Test func dropsBlankAndOversizedText() throws {
        #expect(try offered(" \n\t") == nil)
        let max = String(repeating: "a", count: ShareHandoff.maxTextBytes)
        #expect(try offered(max)?.utf8.count == ShareHandoff.maxTextBytes)
        #expect(try offered(max + "a") == nil)
    }

    @Test func discardingTheBatchForgetsTheText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        try stageBatch(text: "secret", in: inbox)
        let model = ShareInbox()
        model.refresh(in: inbox)
        let batch = try #require(model.batch)
        #expect(model.text == "secret")

        model.discard(batch)
        model.refresh(in: inbox)

        #expect(model.text == nil)
        #expect(model.batch == nil)
    }

    @Test func manifestsWithoutTextStillDecode() throws {
        let json = Data(#"{"files":["a"]}"#.utf8)
        let manifest = try JSONDecoder().decode(ShareHandoff.Manifest.self, from: json)
        #expect(manifest.text == nil)
    }

    @Test func joinTextSkipsBlankParts() {
        #expect(ShareHandoff.joinText(["a", " ", "b"]) == "a\nb")
        #expect(ShareHandoff.joinText(["", "\n"]) == nil)
    }
}
