import Foundation

/// The security scopes the transfer in flight holds open: the files it sends,
/// or the user-picked folder it receives into. Released when its event stream
/// ends, or on reset.
struct SecurityScopes {
    private var urls: [URL] = []

    /// `startAccessingSecurityScopedResource()` returns false for a URL that
    /// is not scoped (some drops). Such a URL is still readable; only the
    /// ones that need a release are kept.
    mutating func open(_ urls: [URL]) {
        self.urls += urls.filter { $0.startAccessingSecurityScopedResource() }
    }

    mutating func releaseAll() {
        for url in urls { url.stopAccessingSecurityScopedResource() }
        urls = []
    }
}
