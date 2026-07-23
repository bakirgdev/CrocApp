#if os(macOS)
import AppKit

/// Receives file-open events (Dock-icon drops, Finder "Open With") and routes
/// them to the Send flow. SwiftUI has no scene-level equivalent for
/// application(_:open:) in a non-document app, hence the delegate adaptor.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        AppRouter.shared.openSend(with: urls)
    }
}
#endif
