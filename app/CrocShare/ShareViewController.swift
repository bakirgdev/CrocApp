import SwiftUI

#if os(macOS)
import AppKit

final class ShareViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let items = (extensionContext?.inputItems ?? []).compactMap { $0 as? NSExtensionItem }
        let root = ShareStagingView(
            items: items,
            complete: { [weak self] in self?.openHostApp() },
            cancel: { [weak self] error in
                self?.extensionContext?.cancelRequest(withError: error)
            })
        let host = NSHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.width, .height]
        view.addSubview(host.view)
    }

    // Unlike iOS, an extension here may launch its own host app, so the user
    // lands on the staged-files sheet instead of having to open CrocApp. The
    // host is derived from this bundle's path, so the App Store and Direct
    // builds each open their own copy.
    private func openHostApp() {
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // CrocApp.app
        Task {
            do {
                try await NSWorkspace.shared.openApplication(
                    at: app, configuration: NSWorkspace.OpenConfiguration())
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                extensionContext?.cancelRequest(withError: error)
            }
        }
    }
}
#else
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = (extensionContext?.inputItems ?? []).compactMap { $0 as? NSExtensionItem }
        let root = ShareStagingView(
            items: items,
            complete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            cancel: { [weak self] error in
                self?.extensionContext?.cancelRequest(withError: error)
            })
        let host = UIHostingController(rootView: root)
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)
    }
}
#endif
