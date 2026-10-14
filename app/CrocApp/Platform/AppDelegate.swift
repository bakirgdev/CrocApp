#if os(macOS)
import AppKit

/// Receives open events: file drops (Dock icon, Finder "Open With") go to the
/// Send flow, receive links (crocapp:// and universal links) to Receive.
/// SwiftUI has no scene-level equivalent for application(_:open:) in a
/// non-document app, hence the delegate adaptor.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { AppRouter.shared.openSend(with: files) }
        for url in urls where !url.isFileURL {
            if let link = TransferLink.parse(url.absoluteString) { AppRouter.shared.open(link) }
        }
    }
}
#endif
