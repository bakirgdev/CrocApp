import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum Clipboard {
    /// `thisDeviceOnly` keeps the text off Universal Clipboard (iOS only; the
    /// macOS pasteboard has no such option). For a stored link, whose
    /// fragment is the decryption key.
    static func copy(_ string: String, thisDeviceOnly: Bool = false) {
        #if os(iOS)
        if thisDeviceOnly {
            UIPasteboard.general.setItems(
                [[UIPasteboard.typeAutomatic: string]], options: [.localOnly: true])
        } else {
            UIPasteboard.general.string = string
        }
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
