import Foundation
import Observation

/// App-wide navigation plus externally-injected send payloads (window drop,
/// dock-icon drop, menu commands). Singleton: NSApplicationDelegate and menu
/// Commands live outside the SwiftUI environment graph and need a stable
/// reference. (Module default actor isolation is MainActor.)
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Route: Hashable { case send, receive }

    var path: [Route] = []
    /// URLs waiting for SendView to pick up into its staged list.
    var pendingSendURLs: [URL] = []

    func openSend(with urls: [URL]) {
        pendingSendURLs.append(contentsOf: urls)
        if path != [.send] { path = [.send] }
    }

    func openReceive() {
        if path != [.receive] { path = [.receive] }
    }
}
