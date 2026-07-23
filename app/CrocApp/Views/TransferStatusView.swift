import SwiftUI
import CrocKit

/// Renders every non-idle controller phase. Shared by Send and Receive flows.
struct TransferStatusView: View {
    @Environment(TransferController.self) private var controller

    var body: some View {
        VStack(spacing: 24) {
            switch controller.phase {
            case .idle:
                EmptyView()
            case .starting:
                ProgressView()
                Text("Starting…").foregroundStyle(.secondary)
            case .connecting:
                ProgressView()
                Text("Connecting…").foregroundStyle(.secondary)
            case .waiting(let code):
                waitingView(code: code)
            case .incoming(let list, let conflicts, let blocked):
                IncomingRequestView(list: list, conflicts: conflicts, blocked: blocked)
            case .transferring(let progress):
                transferringView(progress)
            case .done(let summary, let receivedText):
                doneView(summary, receivedText: receivedText)
            case .failed(let message):
                failedView(message)
            }

            if showsCancel {
                Button("Cancel", role: .destructive) { controller.cancel() }
            }
        }
        .padding()
        .frame(maxWidth: 480)
    }

    private var showsCancel: Bool {
        switch controller.phase {
        case .starting, .waiting, .connecting, .transferring: return true
        default: return false
        }
    }

    // MARK: - Waiting (sender: code ready)

    private func waitingView(code: String) -> some View {
        VStack(spacing: 16) {
            Text("Ready to send").font(.headline)
            Text(code)
                .font(.title2.monospaced().bold())
                .textSelection(.enabled)
            Button {
                Clipboard.copy(code)
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            QRCodeView(content: "croc://\(code)")
            Text("On the other device, enter this code or scan the QR.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ProgressView()
            Text("Waiting for the receiver…").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Transferring

    private func transferringView(_ p: TransferProgress) -> some View {
        VStack(spacing: 16) {
            Text(controller.direction == .send ? "Sending" : "Receiving")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.fileName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: fraction(p.fileSent, of: p.fileSize))
                HStack {
                    Text("File \(min(p.currentFile + 1, p.totalFiles)) of \(p.totalFiles)")
                    Spacer()
                    Text("\(p.fileSent.formatted(.byteCount(style: .file))) / \(p.fileSize.formatted(.byteCount(style: .file)))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: fraction(p.bytesFinished + p.fileSent, of: p.totalSize))
                HStack {
                    Text("Total \((p.bytesFinished + p.fileSent).formatted(.byteCount(style: .file))) / \(p.totalSize.formatted(.byteCount(style: .file)))")
                    Spacer()
                    if controller.speedBytesPerSec > 0 {
                        Text("\(Int64(controller.speedBytesPerSec).formatted(.byteCount(style: .file)))/s")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func fraction(_ part: Int64, of whole: Int64) -> Double {
        whole > 0 ? min(1, Double(part) / Double(whole)) : 0
    }

    // MARK: - Done / Failed

    private func doneView(_ summary: Summary, receivedText: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: summary.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(summary.success ? .green : .orange)
            if let receivedText {
                Text("Received text").font(.headline)
                ScrollView {
                    Text(receivedText)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
                Button {
                    Clipboard.copy(receivedText)
                } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            } else {
                Text(summary.success ? "Transfer complete" : "Transfer finished with problems")
                    .font(.headline)
                Text("\(summary.files) file(s) • \(summary.totalSize.formatted(.byteCount(style: .file)))")
                    .foregroundStyle(.secondary)
            }
            Button("Done") { controller.reset() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
            Button("OK") { controller.reset() }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Incoming file list preview with accept/decline (F9), conflict warning (F8),
/// and unsafe-name blocking.
struct IncomingRequestView: View {
    @Environment(TransferController.self) private var controller
    let list: FileList
    let conflicts: [String]
    let blocked: [String]

    var body: some View {
        VStack(spacing: 16) {
            Text("Incoming transfer").font(.headline)
            List(list.files, id: \.name) { entry in
                HStack {
                    Text(entry.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(entry.size.formatted(.byteCount(style: .file)))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 120, maxHeight: 240)
            Text("\(list.files.count) file(s) • \(list.totalSize.formatted(.byteCount(style: .file)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !blocked.isEmpty {
                Label("Blocked: unsafe file names in this transfer.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if !conflicts.isEmpty {
                Label("\(conflicts.count) item(s) already exist and will be replaced. Partially received files resume.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 16) {
                Button("Decline", role: .destructive) { controller.respond(accept: false) }
                Button("Accept") { controller.respond(accept: true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!blocked.isEmpty)
            }
        }
    }
}
