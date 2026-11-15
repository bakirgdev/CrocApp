#if os(macOS)
import Accessibility
import AppKit
import CrocKit
import SwiftUI

struct MenuBarQuickSendView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.openWindow) private var openWindow
    let quickSend: MenuBarQuickSend
    @State private var isDropTargeted = false
    @State private var code = ""

    private static let windowWidth: CGFloat = 300

    var body: some View {
        VStack(spacing: 12) {
            content
            Divider()
            Button("Open CrocApp") { openMainWindow() }
                .buttonStyle(.borderless)
        }
        .padding()
        .frame(width: Self.windowWidth)
    }

    @ViewBuilder private var content: some View {
        switch controller.phase {
        case .idle:
            idle
        case .starting, .connecting:
            VStack {
                ProgressView().accessibilityHidden(true)
                Text("Connecting…").foregroundStyle(.secondary)
                cancelButton
            }
        case .waiting(let code):
            waiting(code: code)
        case .confirmSend:
            VStack {
                Text("The other device is connected. Send now?").multilineTextAlignment(.center)
                HStack {
                    cancelButton
                    Button("Send") { controller.respond(accept: true) }
                        .buttonStyle(.glassProminent)
                }
            }
        case .incoming:
            VStack {
                Label("Files are waiting for your answer", systemImage: "arrow.down.circle")
                Button("Open CrocApp to Accept") { openMainWindow() }
                    .buttonStyle(.glassProminent)
            }
        case .transferring:
            ProgressTick { transferring($0) }
        case .done(let summary, let receivedText):
            VStack {
                Label(
                    summary.success ? "Transfer complete" : "Transfer finished with errors",
                    systemImage: summary.success
                        ? "checkmark.circle" : "exclamationmark.circle.fill")
                if let receivedText {
                    Button("Copy Received Text") { Clipboard.copy(receivedText) }
                        .buttonStyle(.glass)
                }
                doneButton
            }
        case .stored(let receipt):
            VStack {
                Label("Link ready", systemImage: "checkmark.circle")
                Button("Copy Link") { Clipboard.copySecret(receipt.link, thisDeviceOnly: true) }
                    .buttonStyle(.glass)
                doneButton
            }
        case .failed(let failure):
            VStack {
                StatusBanner(kind: .error, title: failure.title, detail: failure.detail)
                doneButton
            }
        }
    }

    private var idle: some View {
        VStack {
            DropZone(title: "Drop files to send", size: .compact, isTargeted: isDropTargeted)
                .accessibilityLabel("Drop files here to send")
                .dropDestination(for: URL.self) { urls, _ in
                    quickSend.send(urls: urls)
                } isTargeted: {
                    isDropTargeted = $0
                }

            HStack {
                Button("Choose Files…") { quickSend.chooseFiles() }
                    .buttonStyle(.glass)
                Button("Send Clipboard Text") {
                    // A repeat tap leaves the notice unchanged, so an
                    // onChange would stay silent; announce per tap instead.
                    if !quickSend.sendClipboardText(), let notice = quickSend.notice {
                        AccessibilityNotification.Announcement(notice).post()
                    }
                }
                .buttonStyle(.glass)
            }
            Divider()
            CodeField(
                placeholder: "Code phrase", text: $code,
                onPaste: { code = $0 },
                onSubmit: receive, submitLabel: .go)
            Button("Receive") { receive() }
                .buttonStyle(.glassProminent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let notice = quickSend.notice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
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
        VStack {
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
        let done = p.bytesDone
        let total = max(p.totalSize, 1)
        let fraction = min(1, Double(done) / Double(total))
        return VStack {
            DirectionHeader(direction: direction)
            // A batch of small files has no byte count: TransferStatusView.bundleView.
            if p.isBundling {
                Text("A batch of small files")
                ProgressView()
                    .progressViewStyle(.linear)
                    .accessibilityLabel(progressLabel)
            } else {
                Text(p.fileName).lineLimit(1).truncationMode(.middle)
                ForwardProgressBar(fraction: fraction, resetKey: p.totalSize)
                    .accessibilityLabel(progressLabel)
                    .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            }
            Text(
                verbatim: p.isBundling
                    ? p.totalSize.formatted(.byteCount(style: .file))
                    : "\(done.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.totalSize.formatted(.byteCount(style: .file)))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            cancelButton
        }
    }

    private var direction: TransferController.Direction { controller.direction }

    private var progressLabel: LocalizedStringKey {
        direction == .send ? "Sending progress" : "Receiving progress"
    }

    private var cancelButton: some View {
        Button(role: .destructive) {
            controller.cancel()
        } label: {
            Text("Cancel").foregroundStyle(.red)
        }
        .buttonStyle(.glass)
    }

    private var doneButton: some View {
        Button("Done") { controller.reset() }
            .buttonStyle(.glassProminent)
    }

    /// The main scene is a single-instance `Window`, so `openWindow` opens it
    /// when closed and orders the open one to the front.
    private func openMainWindow() {
        NSApp.activate()
        openWindow(id: CrocAppApp.mainWindowID)
    }
}
#endif
