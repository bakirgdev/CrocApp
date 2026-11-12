import Foundation
import Testing

@testable import CrocApp

@MainActor @Suite struct OutputFolderStoreTests {
    private let defaults: UserDefaults
    private let base: URL

    init() throws {
        defaults = try #require(
            UserDefaults(suiteName: "OutputFolderStoreTests-\(UUID().uuidString)"))
        base = FileManager.default.temporaryDirectory.appending(
            path: "CrocAppFolder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private func folder(_ name: String) throws -> URL {
        let url = base.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func aBookmarkResolvesToTheFolderItWasMadeFor() throws {
        let url = try folder("picked")
        let data = try #require(SecurityScopedBookmark.create(for: url))

        let resolved = try #require(SecurityScopedBookmark.resolve(data))
        #expect(resolved.url.standardizedFileURL.path == url.standardizedFileURL.path)
        #expect(!resolved.isStale)
    }

    @Test func aPickedFolderIsKeptAcrossLaunches() throws {
        let url = try folder("picked")
        OutputFolderStore(defaults: defaults).select(url)

        let relaunched = OutputFolderStore(defaults: defaults)
        #expect(relaunched.isUserSelected)
        #expect(relaunched.url.lastPathComponent == "picked")
        #expect(!relaunched.bookmarkWasReset)
    }

    @Test func aStaleBookmarkIsRefreshedNotReset() throws {
        let url = try folder("before")
        OutputFolderStore(defaults: defaults).select(url)
        let moved = base.appending(path: "after", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: url, to: moved)

        let relaunched = OutputFolderStore(defaults: defaults)
        #expect(relaunched.isUserSelected)
        #expect(relaunched.url.lastPathComponent == "after")
        #expect(!relaunched.bookmarkWasReset)
        let stored = try #require(defaults.data(forKey: "outputFolderBookmark"))
        #expect(SecurityScopedBookmark.resolve(stored)?.isStale == false)
    }

    @Test func anUnresolvableBookmarkResetsToTheDefaultFolder() {
        defaults.set(Data("not a bookmark".utf8), forKey: "outputFolderBookmark")

        let store = OutputFolderStore(defaults: defaults)
        #expect(!store.isUserSelected)
        #expect(store.bookmarkWasReset)
        #expect(store.url == OutputFolderStore.defaultFolder)
        #expect(defaults.data(forKey: "outputFolderBookmark") == nil)
    }
}
