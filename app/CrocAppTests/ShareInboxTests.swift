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

    @Test(arguments: [
        "../x", "a/b", "", "..", "x", "batch-", "batch-not-a-uuid",
        "batch-00000000-0000-0000-0000-000000000000/..",
    ])
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

    @Test func aBatchFailingValidationClearsEarlierStaging() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let batch = ShareHandoff.makeBatchName()
        try touch(box.inbox.appendingPathComponent(batch).appendingPathComponent("a.txt"))
        try writeManifest(batch: batch, files: ["a.txt"], in: box.inbox)
        let inbox = ShareInbox()
        inbox.refresh(in: box.inbox)
        #expect(inbox.staged.count == 1)

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

        ShareInbox().refresh(in: box.inbox)

        #expect(exists(live))
        #expect(!exists(stale))
    }

    @Test func purgeDoesNotKeepAnInvalidBatchName() throws {
        let box = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: box.root) }
        let named = box.inbox.appendingPathComponent("x")
        try touch(named.appendingPathComponent("f.txt"))
        try writeManifest(batch: "x", files: ["f.txt"], in: box.inbox)

        ShareInbox().refresh(in: box.inbox)

        #expect(!exists(named))
    }
}
