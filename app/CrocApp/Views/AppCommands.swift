import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// File-menu commands, on the Mac menu bar and the iPadOS 26 menu bar.
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
        #endif
        CommandGroup(replacing: .newItem) {
            Button("Send…") { router.openSend(with: []) }
                .keyboardShortcut("1")
                .disabled(controller.isActive)
            Button("Receive…") { router.openReceive() }
                .keyboardShortcut("2")
                .disabled(controller.isActive)
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
