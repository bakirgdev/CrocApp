import CrocKit
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Renders every non-idle controller phase. Shared by Send and Receive flows.
struct TransferStatusView: View {
    @Environment(TransferController.self) private var controller
    @Environment(LocalNetworkChecker.self) private var localNetwork
    @Environment(OutputFolderStore.self) private var outputFolder
    @State private var showsSlowPhaseHint = false

    // Long enough that ordinary relay/handshake latency doesn't false-positive,
    // short enough to reassure before the user assumes the app is hung.
    private static let slowPhaseThreshold: Duration = .seconds(25)

    private var isInEarlyPhase: Bool {
        switch controller.phase {
        case .starting, .connecting: true
        default: false
        }
    }

    var body: some View {
        VStack(spacing: Spacing.space7) {
            if localNetwork.status == .denied {
                localNetworkDeniedBanner
            }

            switch controller.phase {
            case .idle:
                EmptyView()
            case .starting:
                ProgressView()
                Text("Starting…").foregroundStyle(.secondary)
                if showsSlowPhaseHint {
                    slowPhaseHintText
                }
            case .connecting:
                ProgressView()
                Text("Connecting…").foregroundStyle(.secondary)
                if showsSlowPhaseHint {
                    slowPhaseHintText
                }
            case .confirmSend:
                confirmSendView
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
        .frame(maxWidth: LayoutCap.contentMaxWidth)
        // Resets and restarts whenever isInEarlyPhase flips, so the hint
        // never keeps counting into transferring/done/failed, but survives
        // the starting → connecting handoff (still the same stall to the user).
        .task(id: isInEarlyPhase) {
            showsSlowPhaseHint = false
            guard isInEarlyPhase else { return }
            try? await Task.sleep(for: Self.slowPhaseThreshold)
            guard !Task.isCancelled else { return }
            showsSlowPhaseHint = true
        }
    }

    private var slowPhaseHintText: some View {
        Text(
            "This is taking longer than usual. Double-check the code, or the other device may not be ready."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }

    private var showsCancel: Bool {
        switch controller.phase {
        case .starting, .waiting, .connecting, .transferring, .incoming: return true
        default: return false
        }
    }

    // MARK: - Local network denied

    // The two platforms spell the same pane differently, and naming the wrong
    // one is worse than naming none.
    #if os(iOS)
    private static let localNetworkDeniedDetail =
        "Transfers use the relay only. Enable it in Settings › Privacy & Security › Local Network for faster direct transfers."
    #else
    private static let localNetworkDeniedDetail =
        "Transfers use the relay only. Enable it in System Settings › Privacy & Security › Local Network for faster direct transfers."
    #endif

    // design/colors.md line 107: local-network-denied is `info` (blue), not
    // a warning — the relay path still works, this is a "could be faster"
    // notice, not a problem.
    private var localNetworkDeniedBanner: some View {
        VStack(spacing: Spacing.space3) {
            StatusBanner(
                kind: .info,
                title: "Local network access is off",
                detail: Self.localNetworkDeniedDetail
            )
            Button("Open Settings") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #else
                // Community-standard deep link, not a documented Apple API --
                // same category as shareddocuments:// on the receive side.
                // Measured on macOS 26: this opens Privacy & Security at the
                // top; the ?Privacy_LocalNetwork anchor does not select the
                // Local Network row (nor does the .PrivacySecurity.extension
                // spelling). The banner names the rest of the path, so the
                // user finishes the last hop. Recheck if Apple ever honours it.
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
                ) {
                    NSWorkspace.shared.open(url)
                }
                #endif
            }
            .font(.footnote)
        }
    }

    // MARK: - Waiting (sender: code ready)

    private func waitingView(code: String) -> some View {
        VStack(spacing: Spacing.space5) {
            Text("Ready to send").font(.headline)
            Text(code)
                .codeHeroTextStyle()
                .textSelection(.enabled)
                .accessibilityLabel("Transfer code")
                .accessibilityValue(code.replacingOccurrences(of: "-", with: ", "))
                .padding(.horizontal, Spacing.space6)
                .padding(.vertical, Spacing.space4)
                .glassEffect()
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
            TrustBadge(relay: controller.activeRelay)
            ProgressView()
            Text("Waiting for the receiver…").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Confirm send (F19 both-sides confirm)

    private var confirmSendView: some View {
        VStack(spacing: Spacing.space5) {
            // Decorative icon, size and status-tint both from the component's
            // own judgment (not a speced component) — colors.md rule 2 allows
            // a status color as an icon fill, just never as a label.
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text("Receiver connected").font(.headline)
            Text("Send the selected items to the connected device?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TrustBadge(relay: controller.activeRelay)
            HStack(spacing: Spacing.space5) {
                Button("Cancel", role: .destructive) { controller.cancel() }
                Button("Send") { controller.respond(accept: true) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Transferring

    private func transferringView(_ p: TransferProgress) -> some View {
        VStack(spacing: Spacing.space5) {
            // components.md → TransferProgress: direction header carries the
            // arrow glyph AND the word — neither is optional.
            HStack(spacing: Spacing.space3) {
                Image(systemName: controller.direction == .send ? "arrow.up" : "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentFill)
                    .accessibilityHidden(true)
                Text(controller.direction == .send ? "Sending" : "Receiving")
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text(p.fileName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: fraction(p.fileSent, of: p.fileSize))
                    .accessibilityLabel("Current file progress")
                HStack {
                    Text("File \(min(p.currentFile + 1, p.totalFiles)) of \(p.totalFiles)")
                    Spacer()
                    Text(
                        // spellsOutZero: the default renders the first moments
                        // of every transfer as "Zero kB / 41 MB".
                        "\(p.fileSent.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.fileSize.formatted(.byteCount(style: .file)))"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: Spacing.space3) {
                ProgressView(value: fraction(p.bytesFinished + p.fileSent, of: p.totalSize))
                    .accessibilityLabel("Overall progress")
                HStack {
                    Text(
                        "Total \((p.bytesFinished + p.fileSent).formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.totalSize.formatted(.byteCount(style: .file)))"
                    )
                    Spacer()
                    if controller.speedBytesPerSec > 0 {
                        Text(
                            "\(Int64(controller.speedBytesPerSec).formatted(.byteCount(style: .file)))/s"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            TrustBadge(relay: controller.activeRelay)
        }
    }

    private func fraction(_ part: Int64, of whole: Int64) -> Double {
        whole > 0 ? min(1, Double(part) / Double(whole)) : 0
    }

    // Combines the store's live selection flag with a standardized path
    // check against the current default, rather than trusting either alone:
    // isUserSelected can't drift stale here (this only runs while the
    // receive-done screen from that same folder is on screen), and the path
    // check is the actual "inside our container" guarantee shareddocuments://
    // needs.
    private func isDefaultOutputFolder(_ folder: URL) -> Bool {
        !outputFolder.isUserSelected
            && folder.standardizedFileURL.path
                == OutputFolderStore.defaultFolder.standardizedFileURL.path
    }

    // MARK: - Done / Failed

    private func doneView(_ summary: Summary, receivedText: String?) -> some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(
                kind: summary.success ? .success : .error,
                title: receivedText != nil
                    ? "Received text"
                    : (summary.success ? "Transfer complete" : "Transfer finished with problems"),
                detail: receivedText == nil
                    ? "\(summary.files) file(s) • \(summary.totalSize.formatted(.byteCount(style: .file)))"
                    : nil
            )
            if let receivedText {
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
            }
            if controller.direction == .receive, let folder = controller.lastOutputFolder {
                #if os(iOS)
                // shareddocuments:// only resolves paths inside the app's own
                // container -- a fileImporter-picked iCloud Drive or other
                // provider folder isn't reachable through it, so only offer
                // the button when the folder is still our own default.
                if isDefaultOutputFolder(folder) {
                    Button {
                        let target = "shareddocuments://" + folder.path(percentEncoded: true)
                        if let url = URL(string: target) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open in Files", systemImage: "folder")
                    }
                }
                #else
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                #endif
            }
            Button("Done") { controller.reset() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(kind: .error, title: message)
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
        VStack(spacing: Spacing.space5) {
            Text("Incoming transfer").font(.headline)
            List(list.files, id: \.name) { entry in
                HStack {
                    Text(entry.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(entry.size.formatted(.byteCount(style: .file)))
                        .foregroundStyle(.secondary)
                }
            }
            // Without this the List paints the system grouped background
            // behind the rows, which reads as a stray grey slab under the
            // file card whenever the list is shorter than its own frame.
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120, maxHeight: 240)
            Text(
                "\(list.files.count) file(s) • \(list.totalSize.formatted(.byteCount(style: .file)))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if !blocked.isEmpty {
                StatusBanner(kind: .error, title: "Blocked: unsafe file names in this transfer.")
            } else if !conflicts.isEmpty {
                StatusBanner(
                    kind: .warning,
                    title:
                        "\(conflicts.count) item(s) already exist and will be replaced. Partially received files resume."
                )
            }
            HStack(spacing: Spacing.space5) {
                Button("Decline", role: .destructive) { controller.respond(accept: false) }
                Button("Accept") { controller.respond(accept: true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!blocked.isEmpty)
            }
        }
    }
}
