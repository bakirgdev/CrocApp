#if os(macOS)
import AppKit
import CrocKit
import SwiftUI

/// The menu-bar window (R26): drop files or tap a button to send, then the
/// code, QR and progress of whatever transfer the shared controller runs.
struct MenuBarQuickSendView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.openWindow) private var openWindow
    let quickSend: MenuBarQuickSend
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: Spacing.space4) {
            content
            Divider()
            Button("Open CrocApp") { openMainWindow() }
                .buttonStyle(.link)
        }
        .padding(Spacing.space5)
        .frame(width: 300)
    }

    @ViewBuilder private var content: some View {
        switch controller.phase {
        case .idle:
            idle
        case .starting, .connecting:
            VStack(spacing: Spacing.space3) {
                ProgressView()
                Text("Connecting…").foregroundStyle(.secondary)
                cancelButton
            }
        case .waiting(let code):
            waiting(code: code)
        case .confirmSend:
            VStack(spacing: Spacing.space3) {
                Text("The receiver is connected. Send now?").multilineTextAlignment(.center)
                HStack {
                    Button("Cancel", role: .destructive) { controller.cancel() }
                    Button("Send") { controller.respond(accept: true) }
                        .buttonStyle(.borderedProminent)
                }
            }
        case .incoming:
            VStack(spacing: Spacing.space3) {
                Label("Files are waiting for your answer", systemImage: "arrow.down.circle")
                Text("Open CrocApp to review and accept them.")
                    .font(.callout).foregroundStyle(.secondary)
                cancelButton
            }
        case .transferring(let p):
            transferring(p)
        case .done(let summary, let receivedText):
            VStack(spacing: Spacing.space3) {
                Label(
                    summary.success ? "Transfer complete" : "Transfer finished with errors",
                    systemImage: summary.success
                        ? "checkmark.circle.fill" : "exclamationmark.circle")
                if let receivedText {
                    Button("Copy Received Text") { Clipboard.copy(receivedText) }
                }
                doneButton
            }
        case .stored(let receipt):
            VStack(spacing: Spacing.space3) {
                Label("Upload ready", systemImage: "checkmark.circle.fill")
                Button("Copy Link") { Clipboard.copy(receipt.link, thisDeviceOnly: true) }
                doneButton
            }
        case .failed(let message):
            VStack(spacing: Spacing.space3) {
                StatusBanner(kind: .error, title: message)
                doneButton
            }
        }
    }

    private var idle: some View {
        VStack(spacing: Spacing.space3) {
            VStack(spacing: Spacing.space3) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title)
                    .accessibilityHidden(true)
                Text("Drop files to send")
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.separatorToken,
                        style: StrokeStyle(
                            lineWidth: isDropTargeted ? 2 : BorderWidth.hairline, dash: [6, 4]))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Drop files here to send")
            .dropDestination(for: URL.self) { urls, _ in
                quickSend.send(urls: urls)
            } isTargeted: {
                isDropTargeted = $0
            }

            HStack {
                Button("Choose Files…") { quickSend.chooseFiles() }
                Button("Send Clipboard Text") { quickSend.sendClipboardText() }
            }
            if let notice = quickSend.notice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func waiting(code: String) -> some View {
        VStack(spacing: Spacing.space3) {
            Text(direction == .send ? "Ready to send" : "Waiting for the sender…")
                .font(.headline)
            if direction == .send {
                Text(code)
                    .font(.title3.monospaced().weight(.semibold))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Transfer code")
                    .accessibilityValue(code.replacingOccurrences(of: "-", with: ", "))
                Button {
                    Clipboard.copy(code)
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
                QRCodeView(content: TransferLink.webURL(forCode: code)?.absoluteString ?? code)
            }
            cancelButton
        }
    }

    private func transferring(_ p: TransferProgress) -> some View {
        let done = p.bytesFinished + p.fileSent
        return VStack(spacing: Spacing.space3) {
            Text(p.fileName).lineLimit(1).truncationMode(.middle)
            ProgressView(value: Double(done), total: Double(max(p.totalSize, 1)))
                .accessibilityLabel("Transfer progress")
            cancelButton
        }
    }

    private var direction: TransferController.Direction { controller.direction }

    private var cancelButton: some View {
        Button("Cancel", role: .destructive) { controller.cancel() }
    }

    private var doneButton: some View {
        Button("Done") { controller.reset() }
            .buttonStyle(.borderedProminent)
    }

    private func openMainWindow() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: CrocAppApp.mainWindowID)
        }
    }
}
#endif
