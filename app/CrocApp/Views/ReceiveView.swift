import SwiftUI
import UniformTypeIdentifiers

/// Receive flow (F4 code entry, F6 QR scan + paste, F7 output folder).
struct ReceiveView: View {
    @Environment(TransferController.self) private var controller
    @Environment(OutputFolderStore.self) private var outputFolder
    @Environment(AppRouter.self) private var router

    @State private var code = ""
    /// A stored link (R20) replaces the code field until cleared.
    @State private var storedLink: URL?
    @State private var showScanner = false
    @State private var showFolderPicker = false
    /// Bumped per scanned code; drives the `.selection` haptic.
    @State private var scanCount = 0

    var body: some View {
        Group {
            // Direction matters: isActive alone rendered a running Send under
            // this screen's "Receive" title. Starting one from the fallback
            // form is already a no-op (startReceive's `guard !isActive`).
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

    private var form: some View {
        VStack(spacing: Spacing.space5) {
            if let storedLink {
                storedLinkRow(storedLink)
            } else {
                CodeField(
                    placeholder: "Code phrase",
                    text: $code,
                    isInvalid: !code.isEmpty && code.count < EngineConstraints.minCodeLength,
                    invalidMessage:
                        "A code is at least \(EngineConstraints.minCodeLength) characters."
                ) { pasted in
                    if let link = TransferLink.parse(pasted) { router.open(link) }
                }
                .onChange(of: code) { _, typed in
                    if typed.contains("://"), let link = TransferLink.parse(typed) {
                        router.open(link)
                    }
                }
            }

            #if os(iOS)
            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
            .buttonVariant(.secondary)
            .sheet(isPresented: $showScanner) {
                QRScannerSheet { payload in
                    scanCount += 1
                    if let link = TransferLink.parse(payload) { router.open(link) }
                    showScanner = false
                }
            }
            #endif

            HStack {
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
                Spacer()
                Button {
                    showFolderPicker = true
                } label: {
                    Text("Change…").hitTarget()
                }
                .buttonVariant(.plain)
                .fileImporter(
                    isPresented: $showFolderPicker,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result {
                        outputFolder.select(url)
                    }
                }
                if outputFolder.isUserSelected {
                    Button {
                        outputFolder.resetToDefault()
                    } label: {
                        Text("Reset").hitTarget()
                    }
                    .buttonVariant(.plain)
                }
            }
            .font(.callout)

            Button {
                if let storedLink {
                    controller.startStoreReceive(
                        link: storedLink, into: outputFolder.url,
                        folderIsScoped: outputFolder.isUserSelected)
                } else {
                    controller.startReceive(
                        code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                        into: outputFolder.url,
                        folderIsScoped: outputFolder.isUserSelected)
                }
            } label: {
                Label("Receive", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonVariant(.prominent)
            .controlSize(.large)
            .disabled(
                storedLink == nil
                    && code.trimmingCharacters(in: .whitespacesAndNewlines).count
                        < EngineConstraints.minCodeLength
            )
        }
        .padding(Spacing.space5)
        .frame(maxWidth: LayoutCap.contentMaxWidth)
        .phoneHaptic(trigger: scanCount) { _, _ in .selection }
    }

    private func storedLinkRow(_ url: URL) -> some View {
        let host = TransferController.codeHint(storedLink: url)
        return HStack(spacing: Spacing.space3) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text("Receive from Link")
                    Text(host)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
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
                Text("Clear").hitTarget()
            }
            .buttonVariant(.plain)
            .accessibilityLabel("Clear link")
        }
        .padding(.horizontal, Spacing.space4)
        .frame(minHeight: ControlHeight.large)
        .background(
            Color.surfaceBase, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.separatorToken, lineWidth: BorderWidth.hairline)
        )
    }
}

extension View {
    /// design/accessibility.md → Hit targets: bare text buttons still get a
    /// 44pt target on iOS. macOS keeps its own control sizing.
    fileprivate func hitTarget() -> some View {
        #if os(iOS)
        frame(minWidth: ControlHeight.hitTargetMin, minHeight: ControlHeight.hitTargetMin)
            .contentShape(Rectangle())
        #else
        self
        #endif
    }
}
