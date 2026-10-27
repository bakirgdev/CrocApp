import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The menu bar, on the Mac and in the iPadOS 26 hardware-keyboard menu bar.
/// Anything a toolbar button can do, a menu item can do with a shortcut
/// (design/platforms.md → macOS, "Menu bar is a real surface").
/// The receive folder opens in Finder on the Mac and in Files on iPad.
struct AppCommands: Commands {
    let router: AppRouter
    let outputFolder: OutputFolderStore
    let controller: TransferController

    var body: some Commands {
        #if os(macOS)
        CommandGroup(replacing: .appInfo) {
            Button("About CrocApp") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [
                    .credits: Self.aboutCredits
                ])
            }
        }
        #else
        // The Mac has the Settings scene and its own ⌘, item.
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { router.showSettings() }
                .keyboardShortcut(",")
        }
        #endif
        CommandGroup(replacing: .newItem) {
            Button("Send…") { router.openSend(with: []) }
                .keyboardShortcut("1")
                .disabled(controller.isActive)
            Button("Send Clipboard Text…") { sendClipboardText() }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(controller.isActive)
            Button("Receive…") { router.openReceive() }
                .keyboardShortcut("2")
                .disabled(controller.isActive)
            Button("Paste Code…") { pasteCode() }
                .keyboardShortcut("2", modifiers: [.command, .option])
                .disabled(controller.isActive)
            Button("History") { router.showHistory() }
                .keyboardShortcut("3")
            Divider()
            #if os(macOS)
            Button("Show Receive Folder in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([outputFolder.url])
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            #else
            Button("Show Receive Folder in Files") {
                // Files opens at a folder through its shareddocuments scheme.
                if let path = outputFolder.url.path.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed),
                    let url = URL(string: "shareddocuments://" + path)
                {
                    UIApplication.shared.open(url)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            #endif
        }
        CommandMenu("Transfer") {
            Button("Cancel Transfer") { controller.cancel() }
                .keyboardShortcut(".")
                .disabled(!controller.phase.canCancel)
            Button("Copy Code") {
                if let code = controller.phase.shownCode { Clipboard.copySecret(code) }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(controller.phase.shownCode == nil)
        }
        CommandGroup(replacing: .help) {
            Button("How It Works") { router.showHowItWorks() }
                .keyboardShortcut("?")
        }
    }

    /// Opens Send with the pasteboard's text in its Text tab. Never starts a
    /// send: the user taps Send, the same rule as a dropped file.
    private func sendClipboardText() {
        let text = Self.pasteboardText()?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty {
            router.openSend(text: text)
        } else {
            router.openSend(with: [])
        }
    }

    /// Opens Receive with the pasteboard's code phrase or link in the code
    /// field. Never connects: the user taps Receive, the same rule as a link
    /// that opens the app.
    private func pasteCode() {
        if let text = Self.pasteboardText(), let link = TransferLink.parse(text) {
            router.open(link)
        } else {
            router.openReceive()
        }
    }

    private static func pasteboardText() -> String? {
        #if os(macOS)
        NSPasteboard.general.string(forType: .string)
        #else
        UIPasteboard.general.string
        #endif
    }

    #if os(macOS)
    // The panel draws credits as plain rich text, so size, alignment and the
    // adaptive label color have to be set here to match the rest of the panel.
    private static var aboutCredits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return NSAttributedString(
            string: String(localized: "Privacy Policy"),
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
                .link: AppInfo.privacyURL,
            ])
    }
    #endif
}
