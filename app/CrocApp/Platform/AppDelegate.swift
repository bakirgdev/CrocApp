#if os(macOS)
import AppKit

/// Receives open events: file drops (Dock icon, Finder "Open With") go to the
/// Send flow, receive links (crocapp:// and universal links) to Receive.
/// SwiftUI has no scene-level equivalent for application(_:open:) in a
/// non-document app, hence the delegate adaptor. It also registers the
/// Services provider.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let servicesProvider = SendServicesProvider()

    /// The Services menu entry "Send with CrocApp" (`SendServicesProvider`).
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = servicesProvider
    }

    /// A SwiftUI `Window` as the main scene quits the app when it closes. This
    /// app outlives its window: a transfer keeps running and the menu-bar item
    /// stays (the old `WindowGroup` behavior).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { AppRouter.shared.openSend(with: files) }
        for url in urls where !url.isFileURL {
            if let link = TransferLink.parse(url.absoluteString) { AppRouter.shared.open(link) }
        }
    }
}
#endif
