import Accessibility
import SwiftUI
import UniformTypeIdentifiers

struct ReceiveView: View {
    @Environment(TransferController.self) private var controller
    @Environment(OutputFolderStore.self) private var outputFolder
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var code = ""
    /// A stored link replaces the code field until cleared.
    @State private var storedLink: URL?
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
                    .onChange(of: router.pendingReceive, initial: true) { _, link in
                        guard let link else { return }
                        router.pendingReceive = nil
                        switch link {
                        case .code(let linked):
                            code = linked
                            storedLink = nil
                        case .stored(let url):
                            storedLink = url
                            code = ""
                        }
                    }
            }
        }
        .navigationTitle("Receive")
    }

    // At accessibility text sizes the form is taller than a phone screen, so it
    // scrolls there (as SendView does, and for the same reason: not
    // ViewThatFits, which would swap branches when the keyboard opens).
    private var form: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { formContent.padding() }
            } else {
                formContent.padding()
            }
        }
        .frame(maxWidth: 480)
        .phoneHaptic(trigger: scanCount) { _, _ in .selection }
    }

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canStart: Bool {
        storedLink != nil || EngineConstraints.isValidCode(trimmedCode)
    }

    /// Starts the receive when there is something valid to receive. Return and
    /// the Receive button both come here, and `start(_:)` ignores a second call.
    private func start() {
        guard canStart else { return }
        controller.start(
            TransferRequest(
                storedLink.map(TransferLink.stored) ?? .code(trimmedCode), into: outputFolder))
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            if let storedLink {
                storedLinkRow(storedLink)
            } else {
                VStack(alignment: .leading) {
                    CodeField(
                        placeholder: "Code phrase",
                        text: $code,
                        isInvalid: !code.isEmpty && !EngineConstraints.isValidCode(code),
                        invalidMessage: CodeField.tooShortMessage,
                        onPaste: { pasted in
                            if let link = TransferLink.parse(pasted) { router.open(link) }
                        },
                        onSubmit: start,
                        submitLabel: .go,
                        focusesOnAppear: HardwareKeyboard.isExpected
                    )
                    .onChange(of: code) { _, typed in
                        if typed.contains("://"), let link = TransferLink.parse(typed) {
                            router.open(link)
                        }
                    }
                    SavedCodePicker(selection: code) { code = $0 }
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
                    router.open(link)
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
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    outputFolder.select(url)
                }
            }

            Button(action: start) {
                Label("Receive", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!canStart)
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
                    storedLink = nil
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Clear link")
            }
        }
    }
}
