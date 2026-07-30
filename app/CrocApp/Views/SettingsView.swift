#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// macOS Settings scene (⌘,): receive folder plus the power options (F13-F19).
struct SettingsView: View {
    @Environment(OutputFolderStore.self) private var outputFolder
    @State private var showFolderPicker = false

    /// F.3: the Address field in PowerSettingsSections is the first
    /// focusable control in the Form, so macOS puts a blinking caret in it
    /// the moment the window opens (visible in capture-screenshots.sh's
    /// output). Steering default focus to this button instead — a real,
    /// already-visible control — sidesteps the caret without an untested
    /// invisible placeholder.
    private enum FocusTarget: Hashable {
        case showInFinder
    }
    @FocusState private var focusedControl: FocusTarget?

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
                .focused($focusedControl, equals: .showInFinder)
            }

            PowerSettingsSections()
        }
        .defaultFocus($focusedControl, .showInFinder)
        .formStyle(.grouped)
        // minWidth, not a fixed width: the window is resizable now, and a
        // fixed-width form inside a wider window leaves dead margins on both
        // sides instead of growing with it.
        .frame(minWidth: 480, minHeight: 420)
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
