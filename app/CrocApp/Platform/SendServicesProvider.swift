#if os(macOS)
import AppKit

/// The Services menu entry **Send with CrocApp**, for selected files in Finder
/// and selected text in any app. It stages what was selected in the Send screen
/// and brings the app forward; it never starts a transfer, the same rule as a
/// deep link or a drop (`AppRouter.openSend`). While a transfer runs the router
/// keeps the screen and only queues what was selected.
///
/// The two methods are the `NSMessage` values of the `NSServices` entries in
/// `Config/CrocApp-macOS-Info.plist` and `CrocApp-Direct-Info.plist`; keep the
/// names in step. AppKit calls them on the main thread, with the service's
/// pasteboard.
final class SendServicesProvider: NSObject {
    private let router: AppRouter

    init(router: AppRouter = .shared) {
        self.router = router
    }

    /// The service the system registers at launch (`NSApp.servicesProvider`).
    @objc func sendFiles(
        _ pasteboard: NSPasteboard, userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard stageFiles(from: pasteboard) else {
            error.pointee = Self.nothingToSend as NSString
            return
        }
        NSApp.activate()
    }

    @objc func sendText(
        _ pasteboard: NSPasteboard, userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard stageText(from: pasteboard) else {
            error.pointee = Self.nothingToSend as NSString
            return
        }
        NSApp.activate()
    }

    /// False when the pasteboard holds no file. Files and folders both stage;
    /// the send itself validates them.
    func stageFiles(from pasteboard: NSPasteboard) -> Bool {
        let urls =
            pasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        router.openSend(with: urls)
        return true
    }

    /// False when the pasteboard holds no text, or only whitespace.
    func stageText(from pasteboard: NSPasteboard) -> Bool {
        guard let text = pasteboard.string(forType: .string),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        router.openSend(text: text)
        return true
    }

    /// Shown by the system when a service has nothing to work on; the same
    /// words as the Shortcuts actions.
    private static var nothingToSend: String {
        String(localized: "There is nothing to send.")
    }
}
#endif
