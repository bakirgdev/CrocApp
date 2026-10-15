#if os(macOS)
import AppKit
import Observation

/// What the menu-bar window (R26) does on the user's behalf. A thin layer over
/// the one `TransferController`: it never holds transfer state of its own, so
/// the window shows a transfer started anywhere in the app.
@MainActor
@Observable
final class MenuBarQuickSend {
    private let controller: TransferController

    /// Why the last tap did nothing, for the window to show.
    private(set) var notice: String?

    init(controller: TransferController) {
        self.controller = controller
    }

    /// Sends files and folders with a generated code. Returns false when
    /// nothing was started (a transfer is running, or `urls` has no file).
    @discardableResult
    func send(urls: [URL]) -> Bool {
        let files = urls.filter(\.isFileURL)
        guard !controller.isActive, !files.isEmpty else { return false }
        notice = nil
        controller.startSend(urls: files, customCode: "")
        return true
    }

    @discardableResult
    func sendClipboardText() -> Bool {
        guard !controller.isActive else { return false }
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = "The clipboard has no text to send."
            return false
        }
        notice = nil
        controller.startSendText(text, customCode: "")
        return true
    }

    /// A modal panel: the window-style menu-bar extra closes when focus moves
    /// to a SwiftUI file importer's sheet, taking the importer with it.
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Send"
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        send(urls: panel.urls)
    }
}
#endif
