import Foundation

enum ReceivedName {
    /// True when a name from an incoming file list must block the transfer:
    /// absolute path, parent-directory traversal, backslash, or NUL byte.
    /// Plain relative subpaths ("folder/file.txt") are legitimate for
    /// folder transfers and stay allowed.
    static func isUnsafe(_ name: String) -> Bool {
        if name.isEmpty || name.hasPrefix("/") || name.contains("\\") || name.contains("\0") {
            return true
        }
        return name.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }
}
