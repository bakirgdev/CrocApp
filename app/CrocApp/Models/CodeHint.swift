import Foundation

/// What history keeps of a code or link: enough to recognise a transfer, never
/// enough to reuse it.
enum CodeHint {
    /// A generated code's first word ("wiry-…", or "7291-…" for a legacy
    /// code) is a third of it at most; any other shape is likely a reusable
    /// custom code, so only its first two characters are kept.
    static func code(_ code: String) -> String {
        let t = code.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return "" }
        let segments = t.split(separator: "-", omittingEmptySubsequences: false)
        if segments.count >= 3, let first = segments.first, (1...5).contains(first.count) {
            return first + "-…"
        }
        return String(t.prefix(2)) + "…"
    }

    /// A stored link carries its id in the path and its key in the fragment,
    /// so history keeps only the server's host.
    static func storedLink(_ url: URL) -> String {
        url.host(percentEncoded: false) ?? ""
    }
}
