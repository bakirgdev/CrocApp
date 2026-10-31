#if os(macOS)
import Accessibility
import AppKit
import CrocKit
import SwiftUI

/// The menu-bar window: drop files or tap a button to send, or enter a code to receive, then the
/// code, QR and progress of whatever transfer the shared controller runs.
struct MenuBarQuickSendView: View {
    @Environment(TransferController.self) private var controller
    @Environment(RelayHostController.self) private var relayHost
    @Environment(\.openWindow) private var openWindow
    let quickSend: MenuBarQuickSend
    @State private var isDropTargeted = false
    @State private var code = ""

    // components.md → MenuBarQuickSend: the window is 300 wide.
    private static let windowWidth: CGFloat = 300

    var body: some View {
        VStack(spacing: Spacing.space4) {
            content
            Divider()
            Toggle(
                "Run a Relay",
                isOn: Binding(get: { relayHost.isRunning }, set: { relayHost.setRunning($0) })
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            if case .failed(let failure) = relayHost.state {
                StatusBanner(kind: .error, title: failure.title, detail: failure.detail)
            }
            Button("Open CrocApp") { openMainWindow() }
                .buttonVariant(.plain)
        }
        .padding(Spacing.space5)
        .frame(width: Self.windowWidth)
    }

    @ViewBuilder private var content: some View {
        switch controller.phase {
        case .idle:
            idle
        case .starting, .connecting:
            VStack(spacing: Spacing.space3) {
                ProgressView().accessibilityHidden(true)
                Text("Connecting…").foregroundStyle(.secondary)
                cancelButton
            }
        case .waiting(let code):
            waiting(code: code)
        case .confirmSend:
            VStack(spacing: Spacing.space3) {
                Text("The other device is connected. Send now?").multilineTextAlignment(.center)
                HStack {
                    cancelButton
                    Button("Send") { controller.respond(accept: true) }
                        .buttonVariant(.prominent)
                }
            }
        case .incoming:
            VStack(spacing: Spacing.space3) {
                Label("Files are waiting for your answer", systemImage: "arrow.down.circle")
                Button("Open CrocApp to Accept") { openMainWindow() }
                    .buttonVariant(.prominent)
            }
        case .transferring:
            if let p = controller.progress { transferring(p) }
        case .done(let summary, let receivedText):
            VStack(spacing: Spacing.space3) {
                Label(
                    summary.success ? "Transfer complete" : "Transfer finished with errors",
                    systemImage: summary.success
                        ? "checkmark.circle" : "exclamationmark.circle.fill")
                if let receivedText {
                    Button("Copy Received Text") { Clipboard.copy(receivedText) }
                        .buttonVariant(.secondary)
                }
                doneButton
            }
        case .stored(let receipt):
            VStack(spacing: Spacing.space3) {
                Label("Link ready", systemImage: "checkmark.circle")
                Button("Copy Link") { Clipboard.copySecret(receipt.link, thisDeviceOnly: true) }
                    .buttonVariant(.secondary)
                doneButton
            }
        case .failed(let failure):
            VStack(spacing: Spacing.space3) {
                StatusBanner(kind: .error, title: failure.title, detail: failure.detail)
                doneButton
            }
        }
    }

    private var idle: some View {
        VStack(spacing: Spacing.space3) {
            DropZone(title: "Drop files to send", size: .compact, isTargeted: isDropTargeted)
                .accessibilityLabel("Drop files here to send")
                .dropDestination(for: URL.self) { urls, _ in
                    quickSend.send(urls: urls)
                } isTargeted: {
                    isDropTargeted = $0
                }

            HStack {
                Button("Choose Files…") { quickSend.chooseFiles() }
                    .buttonVariant(.secondary)
                Button("Send Clipboard Text") {
                    // A repeat tap leaves the notice unchanged, so an
                    // onChange would stay silent; announce per tap instead.
                    if !quickSend.sendClipboardText(), let notice = quickSend.notice {
                        AccessibilityNotification.Announcement(notice).post()
                    }
                }
                .buttonVariant(.secondary)
            }
            Divider()
            CodeField(
                placeholder: "Code phrase", text: $code,
                onPaste: { code = $0 },
                onSubmit: receive, submitLabel: .go)
            Button("Receive") { receive() }
                .buttonVariant(.prominent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let notice = quickSend.notice {
                Text(notice).font(.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func receive() {
        if quickSend.receive(code) {
            code = ""
        } else if let notice = quickSend.notice {
            AccessibilityNotification.Announcement(notice).post()
        }
    }

    private func waiting(code: String) -> some View {
        VStack(spacing: Spacing.space3) {
            if direction == .send {
                CodePhraseDisplay(code: code, compact: true)
                QRCodeView(content: TransferLink.webURL(forCode: code)?.absoluteString ?? code)
            } else {
                Text("Waiting for the sender…").font(.headline)
            }
            cancelButton
        }
    }

    private func transferring(_ p: TransferProgress) -> some View {
        let done = p.bytesFinished + p.fileSent
        let total = max(p.totalSize, 1)
        let fraction = min(1, Double(done) / Double(total))
        return VStack(spacing: Spacing.space3) {
            DirectionHeader(direction: direction)
            Text(p.fileName).lineLimit(1).truncationMode(.middle)
            ForwardProgressBar(fraction: fraction, resetKey: p.totalSize)
                .accessibilityLabel(progressLabel)
                .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            Text(
                verbatim:
                    "\(done.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.totalSize.formatted(.byteCount(style: .file)))"
            )
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .monospacedDigit()
            cancelButton
        }
    }

    private var direction: TransferController.Direction { controller.direction }

    private var progressLabel: LocalizedStringKey {
        direction == .send ? "Sending progress" : "Receiving progress"
    }

    private var cancelButton: some View {
        Button("Cancel", role: .destructive) { controller.cancel() }
            .buttonVariant(.destructiveTinted)
    }

    private var doneButton: some View {
        Button("Done") { controller.reset() }
            .buttonVariant(.prominent)
    }

    /// The main scene is a single-instance `Window`, so `openWindow` opens it
    /// when closed and orders the open one to the front.
    private func openMainWindow() {
        NSApp.activate()
        openWindow(id: CrocAppApp.mainWindowID)
    }
}
#endif
