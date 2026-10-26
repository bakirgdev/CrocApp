import Foundation

/// The rule for a file name that arrives from outside the app: an incoming
/// transfer's file list (`TransferController`) and a share-extension manifest
/// (`ShareInbox`, `ShareStager`). This file sits in `Shared/` so the extension
/// applies the same rule as the app.
enum ReceivedName {
    /// True when a name from an incoming file list must block the transfer:
    /// absolute path, parent-directory traversal, backslash, a control
    /// character (NUL, line breaks, tab, DEL), or a character that changes how
    /// the name reads (bidirectional controls, line and paragraph separators).
    /// Plain relative subpaths ("folder/file.txt") are legitimate for
    /// folder transfers and stay allowed.
    static func isUnsafe(_ name: String) -> Bool {
        if name.isEmpty || name.hasPrefix("/") || name.contains("\\") || name.contains("\0") {
            return true
        }
        if name.unicodeScalars.contains(where: isSpoofingScalar) {
            return true
        }
        return name.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    // Deliberately not all of Unicode "format" (Cf). That category also holds
    // ZERO WIDTH JOINER (emoji sequences such as a family), ZERO WIDTH
    // NON-JOINER (required in Persian and Indic names) and tag characters
    // (subdivision flag emoji), all legitimate in file names. Only what lets a
    // sender make "invoice<U+202E>fdp.exe" read as "invoiceexe.pdf", or break
    // a name across lines, is blocked.
    private static func isSpoofingScalar(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        if properties.isBidiControl { return true }
        switch properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator: return true
        default: return false
        }
    }
}
