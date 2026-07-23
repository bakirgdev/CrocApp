import Foundation
import Observation

/// Receive destination folder (F7). Default: app Documents on iOS,
/// Downloads/CrocApp on macOS (Phase 4). User override persists
/// via bookmark: security-scoped on macOS, plain on iOS (fileImporter URLs
/// are implicitly provider-scoped there; .withSecurityScope is macOS-only).
@MainActor
@Observable
final class OutputFolderStore {
    private static let bookmarkKey = "outputFolderBookmark"

    private(set) var url: URL
    private(set) var isUserSelected: Bool

    static var defaultFolder: URL {
        #if os(macOS)
        // Real ~/Downloads via the downloads.read-write entitlement; a
        // CrocApp subfolder keeps received batches from littering Downloads.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let folder = downloads.appendingPathComponent("CrocApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    var defaultDisplayName: String {
        #if os(macOS)
        "Downloads/CrocApp"
        #else
        "Documents"
        #endif
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.bookmarkKey),
           let resolved = Self.resolve(bookmark: data) {
            url = resolved
            isUserSelected = true
        } else {
            url = Self.defaultFolder
            isUserSelected = false
        }
    }

    func select(_ picked: URL) {
        let hadAccess = picked.startAccessingSecurityScopedResource()
        defer { if hadAccess { picked.stopAccessingSecurityScopedResource() } }
        #if os(macOS)
        let data = try? picked.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
        #else
        let data = try? picked.bookmarkData(includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
        #endif
        guard let data else { return }
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        url = picked
        isUserSelected = true
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        url = Self.defaultFolder
        isUserSelected = false
    }

    private static func resolve(bookmark: Data) -> URL? {
        var isStale = false
        #if os(macOS)
        let resolved = try? URL(resolvingBookmarkData: bookmark,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
        #else
        let resolved = try? URL(resolvingBookmarkData: bookmark,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
        #endif
        return isStale ? nil : resolved
    }
}
