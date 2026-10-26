import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum Clipboard {
    /// How long a copied secret stays on the pasteboard, in seconds.
    static let secretLifetime: TimeInterval = 5 * 60

    /// Plain copy with no expiry, for the user's own content.
    static func copy(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    /// Copies a credential: the code phrase, or a stored link whose `#`
    /// fragment is the decryption key. It leaves the pasteboard after
    /// `secretLifetime`. `thisDeviceOnly` keeps it off Universal Clipboard.
    static func copySecret(_ string: String, thisDeviceOnly: Bool = false) {
        #if os(iOS)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: string]],
            options: secretOptions(thisDeviceOnly: thisDeviceOnly))
        #else
        copySecret(
            string, thisDeviceOnly: thisDeviceOnly, to: .general, lifetime: secretLifetime)
        #endif
    }

    #if os(iOS)
    /// The `setItems` options for a secret, a pure function so a test can read
    /// them without touching the pasteboard.
    static func secretOptions(
        thisDeviceOnly: Bool, now: Date = .now
    ) -> [UIPasteboard.OptionsKey: Any] {
        [
            .expirationDate: now.addingTimeInterval(secretLifetime),
            .localOnly: thisDeviceOnly,
        ]
    }
    #endif

    #if os(macOS)
    /// nspasteboard.org marker that clipboard managers honor: they skip the
    /// item or mask it instead of keeping the secret in their history.
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// The macOS pasteboard has no expiry, so the app clears it itself, and
    /// only while it is running: quit before the lifetime ends and the secret
    /// stays. The clear is skipped if the change count moved, so something
    /// the user copied in the meantime is never wiped. The returned task ends
    /// once that check is done.
    @discardableResult
    static func copySecret(
        _ string: String, thisDeviceOnly: Bool, to pasteboard: NSPasteboard,
        lifetime: TimeInterval
    ) -> Task<Void, Never> {
        let item = NSPasteboardItem()
        item.setString(string, forType: .string)
        item.setData(Data(), forType: concealedType)
        pasteboard.prepareForNewContents(with: thisDeviceOnly ? .currentHostOnly : [])
        pasteboard.writeObjects([item])
        let changeCount = pasteboard.changeCount
        return Task {
            try? await Task.sleep(for: .seconds(lifetime))
            guard !Task.isCancelled, pasteboard.changeCount == changeCount else { return }
            pasteboard.clearContents()
        }
    }
    #endif
}
