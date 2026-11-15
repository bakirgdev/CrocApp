import Accessibility
import SwiftUI
import UniformTypeIdentifiers

struct ReceiveView: View {
    @Bindable var draft: ReceiveDraft
    @Environment(TransferController.self) private var controller
    @Environment(OutputFolderStore.self) private var outputFolder

    @State private var showScanner = false
    @State private var showFolderPicker = false
    /// Bumped per scanned code; drives the `.selection` haptic.
    @State private var scanCount = 0

    var body: some View {
        Group {
            // Direction matters: isActive alone rendered a running Send under
            // this screen's "Receive" title. Starting one from the fallback
            // form is already a no-op (`start(_:)`'s `guard !isActive`).
            if controller.isActive, controller.direction == .receive {
                TransferStatusView()
            } else {
                form
            }
        }
        .navigationTitle("Receive")
    }

    private var form: some View {
        ActionScreen {
            formContent
        } actions: {
            resultAction(prominent: true, action: start) {
                Label("Receive", systemImage: "arrow.down.circle.fill")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canStart)
        }
        .phoneHaptic(trigger: scanCount) { _, _ in .selection }
    }

    private var trimmedCode: String { draft.code.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canStart: Bool {
        !controller.isActive
            && (draft.storedLink != nil || EngineConstraints.isValidCode(trimmedCode))
    }

    /// Starts the receive when there is something valid to receive. Return and
    /// the Receive button both come here, and `start(_:)` ignores a second call.
    private func start() {
        guard canStart else { return }
        let request = TransferRequest(
            draft.storedLink.map(TransferLink.stored) ?? .code(trimmedCode), into: outputFolder)
        if controller.start(request) { draft.started = request }
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            if let storedLink = draft.storedLink {
                storedLinkRow(storedLink)
            } else {
                VStack(alignment: .leading) {
                    CodeField(
                        placeholder: "Code phrase",
                        text: $draft.code,
                        isInvalid: !draft.code.isEmpty
                            && !EngineConstraints.isValidCode(draft.code),
                        invalidMessage: CodeField.tooShortMessage,
                        onPaste: { pasted in
                            if let link = TransferLink.parse(pasted) { draft.apply(link) }
                        },
                        onSubmit: start,
                        submitLabel: .go,
                        focusesOnAppear: HardwareKeyboard.isExpected
                    )
                    .onChange(of: draft.code) { _, typed in
                        if typed.contains("://"), let link = TransferLink.parse(typed) {
                            draft.apply(link)
                        }
                    }
                    SavedCodePicker(selection: draft.code) { draft.code = $0 }
                }
            }

            #if os(iOS)
            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(.glass)
            #if os(iOS)
            .controlSize(.large)
            #endif
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { link in
                    scanCount += 1
                    AccessibilityNotification.Announcement(Self.scannedAnnouncement(link)).post()
                    draft.apply(link)
                    showScanner = false
                }
            }
            #endif

            ViewThatFits(in: .horizontal) {
                HStack {
                    folderLabel
                    Spacer()
                    folderActions
                }
                VStack(alignment: .leading) {
                    folderLabel
                    HStack { folderActions }
                }
            }
            .font(.callout)
            .touchTargets()
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    outputFolder.select(url)
                }
            }
            if outputFolder.selectionFailed {
                StatusBanner(
                    kind: .error, title: OutputFolderStore.selectionFailedTitle,
                    detail: OutputFolderStore.selectionFailedDetail)
            }
        }
    }

    private var folderLabel: some View {
        Label {
            Text(
                outputFolder.isUserSelected
                    ? outputFolder.url.lastPathComponent : outputFolder.defaultDisplayName
            )
            .lineLimit(1)
            .truncationMode(.middle)
        } icon: {
            Image(systemName: "folder")
        }
    }

    @ViewBuilder private var folderActions: some View {
        Button {
            showFolderPicker = true
        } label: {
            Text("Change…")
        }
        .buttonStyle(.glass)
        if outputFolder.isUserSelected {
            Button {
                outputFolder.resetToDefault()
            } label: {
                Text("Reset")
            }
            .buttonStyle(.glass)
        }
    }

    /// principles.md → Haptics: a scan is announced as what it decoded.
    private static func scannedAnnouncement(_ link: TransferLink) -> String {
        switch link {
        case .code: String(localized: "Code scanned")
        case .stored: String(localized: "Link scanned")
        }
    }

    private func storedLinkRow(_ url: URL) -> some View {
        let host = CodeHint.storedLink(url)
        return GroupBox {
            HStack {
                Label {
                    VStack(alignment: .leading) {
                        Text("Receive from Link")
                        Text(host)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } icon: {
                    Image(systemName: "link")
                }
                Spacer()
                Button {
                    draft.storedLink = nil
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.glass)
                .touchTargets()
                .accessibilityLabel("Clear link")
            }
        }
    }
}
