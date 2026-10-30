#if os(macOS)
import AppKit
import Observation

/// What the menu-bar window does on the user's behalf. A thin layer over
/// the one `TransferController`: it never holds transfer state of its own, so
/// the window shows a transfer started anywhere in the app.
@MainActor
@Observable
final class MenuBarQuickSend {
    private let controller: TransferController
    private let outputFolder: OutputFolderStore

    /// Why the last tap did nothing, for the window to show.
    private(set) var notice: String?

    init(controller: TransferController, outputFolder: OutputFolderStore) {
        self.controller = controller
        self.outputFolder = outputFolder
    }

    /// Receives with a code or any link CrocApp opens (`TransferLink`) into the
    /// configured folder, as the Receive intent does. Returns false when
    /// nothing was started, and says why in `notice`.
    @discardableResult
    func receive(_ input: String) -> Bool {
        guard !controller.isActive else { return false }
        guard let link = TransferLink.parse(input) else {
            notice = String(localized: "Enter a code phrase or a download link.")
            return false
        }
        notice = nil
        let folder = outputFolder.url
        let scoped = outputFolder.isUserSelected
        switch link {
        case .code(let code):
            controller.start(.receive(code: code, folder: folder, folderIsScoped: scoped))
        case .stored(let url):
            controller.start(.storedReceive(link: url, folder: folder, folderIsScoped: scoped))
        }
        return true
    }

    /// Sends files and folders with a generated code. Returns false when
    /// nothing was started (a transfer is running, or `urls` has no file).
    @discardableResult
    func send(urls: [URL]) -> Bool {
        let files = urls.filter(\.isFileURL)
        guard !controller.isActive, !files.isEmpty else { return false }
        notice = nil
        controller.start(.sendFiles(urls: files, code: ""))
        return true
    }

    @discardableResult
    func sendClipboardText() -> Bool {
        guard !controller.isActive else { return false }
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = String(localized: "The clipboard has no text to send.")
            return false
        }
        notice = nil
        controller.start(.sendText(text: text, code: ""))
        return true
    }

    /// A modal panel: the window-style menu-bar extra closes when focus moves
    /// to a SwiftUI file importer's sheet, taking the importer with it.
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Send", comment: "Confirm button of the file chooser.")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        send(urls: panel.urls)
    }
}
#endif
