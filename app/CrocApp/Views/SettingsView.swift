#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// macOS Settings scene (⌘,): receive folder plus the power options (F13-F19).
struct SettingsView: View {
    @Environment(OutputFolderStore.self) private var outputFolder
    @State private var showFolderPicker = false

    var body: some View {
        Form {
            Section("Receive") {
                LabeledContent("Save received files to") {
                    HStack(spacing: 8) {
                        Text(
                            outputFolder.isUserSelected
                                ? outputFolder.url.path : outputFolder.defaultDisplayName
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                        Button("Change…") { showFolderPicker = true }
                        if outputFolder.isUserSelected {
                            Button("Reset") { outputFolder.resetToDefault() }
                        }
                    }
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([outputFolder.url])
                }
            }

            PowerSettingsSections()
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                outputFolder.select(url)
            }
        }
    }
}

#Preview { SettingsView().environment(OutputFolderStore()).environment(AppSettings()) }
#endif
