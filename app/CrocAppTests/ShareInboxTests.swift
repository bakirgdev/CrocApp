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

/// The manifest is data read out of the App Group container, so `ShareInbox`
/// treats it as untrusted. Each test works in a temp directory standing in for
/// the container's inbox.
@MainActor
@Suite struct ShareInboxTests {
    /// `root` holds `inbox` plus anything a hostile batch name could reach
    /// from it.
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

    private func writeManifest(batch: String, files: [String], in inbox: URL) throws {
        let data = try JSONEncoder().encode(ShareHandoff.Manifest(batch: batch, files: files))
        try data.write(to: ShareHandoff.manifestURL(in: inbox))
    }

    private func touch(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @Test func stagesTheFilesOfAValidBatch() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let batch = ShareHandoff.makeBatchName()
        let batchDir = box.inbox.appendingPathComponent(batch, isDirectory: true)
        try touch(batchDir.appendingPathComponent("a.txt"))
        try touch(batchDir.appendingPathComponent("b.txt"))
        try writeManifest(batch: batch, files: ["a.txt", "b.txt", "missing.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.map(\.lastPathComponent) == ["a.txt", "b.txt"])
        #expect(inbox.staged.allSatisfy { $0.deletingLastPathComponent().path == batchDir.path })
    }

    @Test func anUnsafeNameDropsOnlyThatName() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let batch = ShareHandoff.makeBatchName()
        let batchDir = box.inbox.appendingPathComponent(batch, isDirectory: true)
        let unsafe = [
            "../escape.txt", "invoice\u{202E}fdp.exe", "line\u{2028}break.txt", "a\\b.txt",
            "/abs.txt",
        ]
        try touch(batchDir.appendingPathComponent("ok.txt"))
        // The names that can exist on disk do, so only the name check can be
        // what drops them.
        try touch(box.inbox.appendingPathComponent("escape.txt"))
        try touch(batchDir.appendingPathComponent("invoice\u{202E}fdp.exe"))
        try touch(batchDir.appendingPathComponent("line\u{2028}break.txt"))
        try writeManifest(batch: batch, files: ["ok.txt"] + unsafe, in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.map(\.lastPathComponent) == ["ok.txt"])
    }

    @Test(arguments: ["../x", "", "..", "x", "batch-", "batch-not-a-uuid"])
    func anInvalidBatchIsIgnored(batch: String) throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        // A file in the directory the name would reach if it were joined to
        // the inbox, and one in a directory outside the inbox.
        let reached = box.inbox.appendingPathComponent(batch, isDirectory: true)
        try touch(reached.appendingPathComponent("f.txt"))
        let outside = box.root.appendingPathComponent("x/f.txt")
        try touch(outside)
        try writeManifest(batch: batch, files: ["f.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.isEmpty)
        #expect(exists(outside))
    }

    /// `purgeStaleBatches` deletes the first component of "a/b" before the
    /// files are looked up, which would hide a missing check. A symlink is not
    /// a directory path, so the purge leaves it and only the batch check stands
    /// between the name and the file.
    @Test(arguments: ["a/b", "batch-00000000-0000-0000-0000-000000000000/.."])
    func aTraversingBatchIsIgnoredEvenWhenPurgeLeavesItsPath(batch: String) throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        // root/target/b/f.txt is reached by "a/b", root/f.txt by "<name>/..".
        let target = box.root.appendingPathComponent("target", isDirectory: true)
        try touch(target.appendingPathComponent("b/f.txt"))
        try touch(box.root.appendingPathComponent("f.txt"))
        let first = String(batch.split(separator: "/")[0])
        try FileManager.default.createSymbolicLink(
            at: box.inbox.appendingPathComponent(first), withDestinationURL: target)
        try writeManifest(batch: batch, files: ["f.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.isEmpty)
        #expect(exists(target.appendingPathComponent("b/f.txt")))
    }

    @Test func aBatchFailingValidationClearsEarlierStaging() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let batch = ShareHandoff.makeBatchName()
        try touch(box.inbox.appendingPathComponent(batch).appendingPathComponent("a.txt"))
        try writeManifest(batch: batch, files: ["a.txt"], in: box.inbox)
        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)
        #expect(inbox.staged.count == 1)

        // The second manifest's batch would reach root/x, which holds the file.
        try touch(box.root.appendingPathComponent("x/a.txt"))
        try writeManifest(batch: "../x", files: ["a.txt"], in: box.inbox)
        inbox.refresh(in: box.inbox)

        #expect(inbox.staged.isEmpty)
    }

    @Test func purgeKeepsOnlyTheBatchAValidManifestNames() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let live = box.inbox.appendingPathComponent(ShareHandoff.makeBatchName())
        let stale = box.inbox.appendingPathComponent(ShareHandoff.makeBatchName())
        try touch(live.appendingPathComponent("a.txt"))
        try touch(stale.appendingPathComponent("b.txt"))
        try writeManifest(batch: live.lastPathComponent, files: ["a.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.now = { .now.addingTimeInterval(2 * ShareInbox.stagingGrace) }
        inbox.refresh(in: box.inbox)

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
        let named = box.inbox.appendingPathComponent("x")
        try touch(named.appendingPathComponent("f.txt"))
        try writeManifest(batch: "x", files: ["f.txt"], in: box.inbox)

        let inbox = ShareInbox()
        inbox.now = { .now.addingTimeInterval(2 * ShareInbox.stagingGrace) }
        inbox.refresh(in: box.inbox)

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

    private func writeManifest(
        files: [String] = [], text: String?, in inbox: URL
    ) throws -> String {
        let batch = ShareHandoff.makeBatchName()
        let dir = inbox.appendingPathComponent(batch, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for file in files { try Data("x".utf8).write(to: dir.appendingPathComponent(file)) }
        let data = try JSONEncoder().encode(
            ShareHandoff.Manifest(batch: batch, files: files, text: text))
        try data.write(to: ShareHandoff.manifestURL(in: inbox))
        return batch
    }

    @Test func readsSharedText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        _ = try writeManifest(text: "https://example.com/a\nhello", in: inbox)

        let model = ShareInbox()
        model.refresh(in: inbox)

        #expect(model.text == "https://example.com/a\nhello")
        #expect(model.staged.isEmpty)
    }

    @Test func filesTakePrecedenceOverText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        _ = try writeManifest(files: ["a.txt"], text: "hello", in: inbox)

        let model = ShareInbox()
        model.refresh(in: inbox)

        #expect(model.staged.count == 1)
        #expect(model.text == nil)
    }

    @Test func dropsBlankAndOversizedText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        let model = ShareInbox()

        _ = try writeManifest(text: " \n\t", in: inbox)
        model.refresh(in: inbox)
        #expect(model.text == nil)

        _ = try writeManifest(
            text: String(repeating: "a", count: ShareHandoff.maxTextBytes), in: inbox)
        model.refresh(in: inbox)
        #expect(model.text?.utf8.count == ShareHandoff.maxTextBytes)

        _ = try writeManifest(
            text: String(repeating: "a", count: ShareHandoff.maxTextBytes + 1), in: inbox)
        model.refresh(in: inbox)
        #expect(model.text == nil)
    }

    @Test func consumingTheManifestForgetsTheText() throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        _ = try writeManifest(text: "secret", in: inbox)
        let model = ShareInbox()
        model.refresh(in: inbox)
        #expect(model.text == "secret")

        try FileManager.default.removeItem(at: ShareHandoff.manifestURL(in: inbox))
        model.refresh(in: inbox)

        #expect(model.text == nil)
    }

    @Test func oldManifestsWithoutTextStillDecode() throws {
        let json = Data(#"{"batch":"b","files":["a"]}"#.utf8)
        let manifest = try JSONDecoder().decode(ShareHandoff.Manifest.self, from: json)
        #expect(manifest.text == nil)
    }

    @Test func joinTextSkipsBlankParts() {
        #expect(ShareHandoff.joinText(["a", " ", "b"]) == "a\nb")
        #expect(ShareHandoff.joinText(["", "\n"]) == nil)
    }
}
