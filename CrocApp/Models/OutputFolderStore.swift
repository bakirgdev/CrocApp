import Foundation
import Observation

/// Receive destination folder (F7). Default: app Documents (Files-visible on
/// iOS once Phase 3 adds the plist keys; sandbox container on macOS until
/// Phase 4 moves the default to Downloads/CrocApp). User override persists
/// via bookmark: security-scoped on macOS, plain on iOS (fileImporter URLs
/// are implicitly provider-scoped there; .withSecurityScope is macOS-only).
@MainActor
@Observable
final class OutputFolderStore {
    private static let bookmarkKey = "outputFolderBookmark"

    private(set) var url: URL
    private(set) var isUserSelected: Bool

    static var defaultFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
