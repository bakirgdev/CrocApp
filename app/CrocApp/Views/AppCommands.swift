import SwiftUI
#if os(macOS)
import AppKit
#endif

/// File-menu commands. Cross-platform (iPad gets them via the menu bar too);
/// Finder reveal is macOS-only.
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
            #if os(macOS)
            Divider()
            Button("Show Receive Folder in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([outputFolder.url])
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            #endif
        }
    }
}
