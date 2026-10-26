#if os(macOS)
import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

/// macOS Settings scene (⌘,): a General tab (receive folder plus the power
/// options) and an Advanced tab. The Advanced controls with
/// their footnotes would roughly double a form that already scrolls, so they
/// get their own tab, the macOS convention for a long settings window.
struct SettingsView: View {
    @Environment(OutputFolderStore.self) private var outputFolder
    @Environment(AppSettings.self) private var settings
    @State private var showFolderPicker = false
    @State private var loginItem = LoginItem()

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
        TabView(selection: Bindable(AppRouter.shared).settingsTab) {
            Tab("General", systemImage: "gearshape", value: .general) { general }
            Tab("Advanced", systemImage: "slider.horizontal.3", value: .advanced) {
                AdvancedSettingsView()
            }
        }
    }

    private var general: some View {
        Form {
            Section("Receive") {
                LabeledContent("Save Received Files To") {
                    HStack(spacing: Spacing.space3) {
                        Text(
                            outputFolder.isUserSelected
                                ? outputFolder.url.path : outputFolder.defaultDisplayName
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                        Button("Change…") { showFolderPicker = true }
                            .buttonVariant(.plain)
                        if outputFolder.isUserSelected {
                            Button("Reset") { outputFolder.resetToDefault() }
                                .buttonVariant(.plain)
                        }
                    }
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([outputFolder.url])
                }
                .buttonVariant(.plain)
                .focused($focusedControl, equals: .showInFinder)
            }

            menuBarSection

            GeneralSettingsSections()

            PowerSettingsSections()

            AboutSection()
        }
        .defaultFocus($focusedControl, .showInFinder)
        .onAppear { loginItem.refresh() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            loginItem.refresh()
        }
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

extension SettingsView {
    @ViewBuilder fileprivate var menuBarSection: some View {
        Section {
            Toggle("Show in Menu Bar", isOn: Bindable(settings).showInMenuBar)
            Toggle(
                "Open at Login",
                isOn: Binding(
                    get: { loginItem.isRegistered }, set: { loginItem.setRegistered($0) })
            )
            .accessibilityHint(loginItem.errorMessage ?? "")
            if loginItem.needsApproval {
                HStack {
                    Text("Allow CrocApp in System Settings > General > Login Items.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Settings") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonVariant(.plain)
                }
            }
            if let message = loginItem.errorMessage {
                StatusBanner(kind: .error, title: message)
            }
        } header: {
            Text("Menu bar")
        } footer: {
            Text("Send files and text from the menu bar without opening the window.")
        }
    }
}

#Preview { SettingsView().environment(OutputFolderStore()).environment(AppSettings()) }
#endif
