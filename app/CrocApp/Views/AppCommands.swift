import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// File-menu commands, on the Mac menu bar and the iPadOS 26 menu bar (R28).
/// The receive folder opens in Finder on the Mac and in Files on iPad.
struct AppCommands: Commands {
    let router: AppRouter
    let outputFolder: OutputFolderStore
    let controller: TransferController

    var body: some Commands {
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
}
