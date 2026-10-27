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
    @Environment(AppRouter.self) private var router
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @State private var showsSlowPhaseHint = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // components.md → StatusBlock/EmptyState: decorative glyph at 44, scaled.
    @ScaledMetric(relativeTo: .largeTitle) private var confirmGlyphSize: CGFloat = 44

    // Long enough that ordinary relay/handshake latency doesn't false-positive,
    // short enough to reassure before the user assumes the app is hung.
    private static let slowPhaseThreshold: Duration = .seconds(25)

    private var isInEarlyPhase: Bool {
        switch controller.phase {
        case .starting, .connecting: true
        default: false
        }
    }

    /// The phase case without its payload: the cross-fade keys on this, not on
    /// every progress tick (design/motion.md → Choreography).
    private enum PhaseKind: Hashable {
        case idle, starting, waiting, connecting, confirmSend, incoming
        case transferring, done, stored, failed
    }

    private var phaseKind: PhaseKind {
        switch controller.phase {
        case .idle: .idle
        case .starting: .starting
        case .waiting: .waiting
        case .connecting: .connecting
        case .confirmSend: .confirmSend
        case .incoming: .incoming
        case .transferring: .transferring
        case .done: .done
        case .stored: .stored
        case .failed: .failed
        }
    }

    var body: some View {
        // The phase content scrolls when taller than the screen (accessibility
        // text sizes) and stays centred when it fits. Not ViewThatFits: it
        // measures the unwrapped ideal height, so wrapping text (link, callout)
        // made it pick the plain branch and clip the bottom of the screen.
        GeometryReader { proxy in
            ScrollView {
                // fixedSize: minHeight proposes the screen height down to the
                // content, which would squeeze wrapping text into ellipses.
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
        }
        .padding(Spacing.space5)
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

    private var content: some View {
        VStack(spacing: Spacing.space7) {
            if localNetwork.status == .denied {
                localNetworkDeniedBanner
            }

            // One cross-fade on the block that swaps; its contents do not
            // animate in separately. The ZStack lets old and new overlap
            // instead of stacking while both are in the tree.
            ZStack {
                phaseContent
                    .id(phaseKind)
                    .transition(.opacity)
            }
            .animation(
                reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: phaseKind)

            if showsCancel {
                Button("Cancel", role: .destructive) { controller.cancel() }
                    .buttonVariant(.destructiveTinted)
            }
        }
    }

    @ViewBuilder private var phaseContent: some View {
        switch controller.phase {
        case .idle:
            EmptyView()
        case .starting:
            earlyPhase("Starting…")
        case .connecting:
            earlyPhase("Connecting…")
        case .confirmSend:
            confirmSendView
        case .waiting(let code):
            waitingView(code: code)
        case .incoming(let list, let conflicts, let blocked):
            IncomingRequestView(list: list, conflicts: conflicts, blocked: blocked)
        case .transferring:
            if let progress = controller.progress { transferringView(progress) }
        case .done(let summary, let receivedText):
            doneView(summary, receivedText: receivedText)
        case .stored(let receipt):
            storedView(receipt)
        case .failed(let failure):
            failedView(failure)
        }
    }

    private func earlyPhase(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.space7) {
            ProgressView().accessibilityHidden(true)
            Text(title).foregroundStyle(Color.textSecondary)
            // Fades in at --dur-slow so it reads as information, not alarm.
            ZStack {
                if showsSlowPhaseHint {
                    slowPhaseHintText.transition(.opacity)
                }
            }
            .animation(
                reduceMotion ? nil : Motion.easeOut(Motion.durationSlow), value: showsSlowPhaseHint)
        }
    }

    private var slowPhaseHintText: some View {
        Text(
            "This is taking longer than usual. Double-check the code, or the other device may not be ready."
        )
        .font(.footnote)
        .foregroundStyle(Color.textSecondary)
        .multilineTextAlignment(.center)
    }

    /// Cancel is not offered at the accept gate: it would answer the sender on
    /// the user's behalf. Decline is the way to say no (components.md → AcceptGate).
    private var showsCancel: Bool {
        switch controller.phase {
        case .starting, .waiting, .connecting, .transferring: return true
        default: return false
        }
    }

    // MARK: - Local network denied

    // The two platforms spell the same pane differently, and naming the wrong
    // one is worse than naming none.
    #if os(iOS)
    private static let localNetworkDeniedDetail = String(
        localized:
            "Transfers use the relay only. Enable it in Settings › Privacy & Security › Local Network for faster direct transfers.",
        comment: "The path names the iOS Settings app. Match its translated pane names.")
    #else
    private static let localNetworkDeniedDetail = String(
        localized:
            "Transfers use the relay only. Enable it in System Settings › Privacy & Security › Local Network for faster direct transfers.",
        comment: "The path names the macOS System Settings app. Match its translated pane names."
    )
    #endif

    // components.md → StatusBanner: local-network-denied is `info` (blue), not
    // a warning. The relay path still works, this is a "could be faster"
    // notice, not a problem.
    private var localNetworkDeniedBanner: some View {
        StatusBanner(
            kind: .info,
            title: String(localized: "Local network access is off"),
            detail: Self.localNetworkDeniedDetail,
            actionTitle: "Open Settings",
            action: { open(.localNetworkAccess) }
        )
    }

    /// Opens where the fix lives (components.md → StatusBlock): CrocApp's own
    /// Settings for one of our settings, the system's for a permission.
    private func open(_ place: SettingsPlace) {
        switch place {
        case .localNetworkAccess:
            openLocalNetworkSettings()
        case .general, .advanced:
            #if os(macOS)
            router.settingsTab = place == .advanced ? .advanced : .general
            openSettings()
            #else
            // Pushed on top, so Back returns to this result.
            router.push(place == .advanced ? [.settings, .advancedSettings] : [.settings])
            #endif
        }
    }

    private func openLocalNetworkSettings() {
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

    // MARK: - Waiting (sender: code ready)

    private func waitingView(code: String) -> some View {
        VStack(spacing: Spacing.space5) {
            CodePhraseDisplay(code: code)
            let webURL = TransferLink.webURL(forCode: code)
            QRCodeView(content: webURL?.absoluteString ?? code)
            if let webURL {
                ShareLink(item: webURL) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
            }
            Text("On the other device, enter this code or scan the QR.")
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            if let note = browserReceiveNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            TrustBadge(relay: controller.activeRelay)
            ProgressView().accessibilityHidden(true)
            Text("Waiting for the other device…").font(.caption).foregroundStyle(
                Color.textSecondary)
        }
    }

    /// croc's browser client only knows the default relays.
    private var browserReceiveNote: LocalizedStringKey? {
        switch controller.activeRelay {
        case .publicDefault, .directToSender: nil
        case .custom:
            "Receiving in a browser needs the default relays. This transfer uses a custom relay."
        case .localOnly:
            "Receiving in a browser needs the default relays. This transfer stays on your local network."
        }
    }

    // MARK: - Confirm send (both-sides confirm)

    private var confirmSendView: some View {
        VStack(spacing: Spacing.space5) {
            // Decorative glyph in a status color: allowed as a fill, never as
            // a label (colors.md → Contrast, rule 2).
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: confirmGlyphSize))
                .foregroundStyle(Color.statusInfo)
                .accessibilityHidden(true)
            Text("The other device is connected").font(.headline)
            Text("Send the selected items to the connected device?")
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            TrustBadge(relay: controller.activeRelay)
            HStack(spacing: Spacing.space5) {
                Button("Cancel", role: .destructive) { controller.cancel() }
                    .buttonVariant(.destructiveTinted)
                Button("Send") { controller.respond(accept: true) }
                    .buttonVariant(.prominent)
                    .controlSize(.large)
            }
        }
    }

    // MARK: - Transferring

    private func transferringView(_ p: TransferProgress) -> some View {
        let fileFraction = fraction(p.fileSent, of: p.fileSize)
        let totalDone = p.bytesFinished + p.fileSent
        let totalFraction = fraction(totalDone, of: p.totalSize)
        return VStack(spacing: Spacing.space5) {
            DirectionHeader(direction: controller.direction)
            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text(p.fileName)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForwardProgressBar(
                    fraction: fileFraction,
                    resetKey: ProgressScope(file: p.currentFile, size: p.fileSize)
                )
                .accessibilityLabel("Current file progress")
                HStack {
                    Text("File \(min(p.currentFile + 1, p.totalFiles)) of \(p.totalFiles)")
                    Spacer()
                    Text(
                        // spellsOutZero: the default renders the first moments
                        // of every transfer as "Zero kB / 41 MB".
                        verbatim:
                            "\(p.fileSent.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.fileSize.formatted(.byteCount(style: .file)))"
                    )
                }
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(percent(fileFraction))
            VStack(alignment: .leading, spacing: Spacing.space3) {
                ForwardProgressBar(
                    fraction: totalFraction, resetKey: ProgressScope(file: -1, size: p.totalSize)
                )
                .accessibilityLabel("Overall progress")
                HStack {
                    Text(
                        "Total \(totalDone.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.totalSize.formatted(.byteCount(style: .file)))"
                    )
                    .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(speedText)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                }
                .font(.caption)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(percent(totalFraction))
            if controller.isStoredTransfer {
                // A stored transfer meets no relay, so the relay badge would
                // describe a path it does not take.
                Text("Encrypted on this device. The link server only holds the encrypted files.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                TrustBadge(relay: controller.activeRelay)
            }
        }
    }

    /// What a progress bar measures. A new scope snaps the bar instead of
    /// letting it run backwards.
    private struct ProgressScope: Hashable {
        let file: Int
        let size: Int64
    }

    /// An unknown or zero speed is an em dash, never "0 B/s": a zero reads as
    /// a stall (content.md → Numbers).
    private var speedText: String {
        guard controller.speedBytesPerSec > 0 else { return "—" }
        return "\(Int64(controller.speedBytesPerSec).formatted(.byteCount(style: .file)))/s"
    }

    private func fraction(_ part: Int64, of whole: Int64) -> Double {
        whole > 0 ? min(1, Double(part) / Double(whole)) : 0
    }

    /// The percentage VoiceOver reads for a combined progress group (on
    /// macOS it lands in `AXValueDescription`, beside the raw fraction).
    private func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
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
                    ? String(localized: "Received text")
                    : (summary.success
                        ? String(localized: "Transfer complete")
                        : String(localized: "Transfer finished with problems")),
                detail: receivedText == nil
                    ? inflected(
                        AttributedString(
                            localized:
                                "^[\(summary.files) file](inflect: true) • \(summary.totalSize.formatted(.byteCount(style: .file)))"
                        ))
                    : nil
            )
            if let receivedText {
                ScrollView {
                    Text(receivedText)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: Self.receivedTextMaxHeight)
                Button {
                    Clipboard.copy(receivedText)
                } label: {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
                .buttonVariant(.secondary)
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
                    .buttonVariant(.secondary)
                }
                #else
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonVariant(.secondary)
                #endif
            }
            Button("Done") { controller.reset() }
                .buttonVariant(.prominent)
                .controlSize(.large)
        }
    }

    private static let receivedTextMaxHeight: CGFloat = 200

    private func storedView(_ receipt: StoredReceipt) -> some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(
                kind: .success, title: "Link ready",
                detail: inflected(
                    AttributedString(
                        localized:
                            "Works until \(receipt.expiresAt.formatted(date: .abbreviated, time: .shortened)), for ^[\(receipt.downloads) download](inflect: true)"
                    ))
            )
            QRCodeView(content: receipt.link, label: "QR code for the link")
            Text(receipt.link)
                .font(.caption.monospaced())
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityLabel("Link")
            HStack(spacing: Spacing.space5) {
                Button {
                    Clipboard.copySecret(receipt.link, thisDeviceOnly: true)
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
                .buttonVariant(.secondary)
                if let url = URL(string: receipt.link) {
                    ShareLink(item: url) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                    }
                }
            }
            Text(
                "Anyone who gets this link can download the files until it expires or runs out. Revoke it any time in History."
            )
            .font(.callout)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            Button("Done") { controller.reset() }
                .buttonVariant(.prominent)
                .controlSize(.large)
        }
    }

    private func failedView(_ failure: TransferFailure) -> some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(kind: .error, title: failure.title, detail: failure.detail)
            // components.md → StatusBlock: Done always, plus the one action
            // that could help, if any.
            VStack(spacing: Spacing.space3) {
                switch failure.remedy {
                case .tryAgain?:
                    failureAction("Try Again") { controller.retry() }
                    failureAction("Done", variant: .secondary) { controller.reset() }
                case .openSettings(let place)?:
                    failureAction("Open Settings") { open(place) }
                    failureAction("Done", variant: .secondary) { controller.reset() }
                case nil:
                    failureAction("Done") { controller.reset() }
                }
            }
        }
    }

    /// A StatusBlock action: large and full width.
    private func failureAction(
        _ title: LocalizedStringKey, variant: ButtonVariant = .prominent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonVariant(variant)
        .controlSize(.large)
    }
}

/// The accept gate. design/components.md → AcceptGate: a phase of the transfer
/// screen, not a sheet or an alert. Decline says no to the other device, Accept
/// (or Keep Both and Replace when a name is taken) says yes. Leaving answers
/// nothing, and there is no Cancel here.
struct IncomingRequestView: View {
    @Environment(TransferController.self) private var controller
    let list: FileList
    let conflicts: [String]
    let blocked: [String]
    @ScaledMetric private var listMaxHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: Spacing.space5) {
            DirectionHeader(direction: .receive)
            TrustBadge(relay: controller.activeRelay)
            ScrollView {
                // A card of rows: FileRow draws the first/last corner rounding
                // and the separators.
                VStack(spacing: 0) {
                    ForEach(Array(list.files.enumerated()), id: \.element.name) { index, entry in
                        FileRow(
                            name: entry.name, size: entry.size,
                            isFirst: index == 0, isLast: index == list.files.count - 1)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: listMaxHeight)
            Text(
                "^[\(list.files.count) file](inflect: true) • \(list.totalSize.formatted(.byteCount(style: .file)))"
            )
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .monospacedDigit()
            if !blocked.isEmpty {
                StatusBanner(
                    kind: .error,
                    title: String(localized: "Blocked: unsafe file names in this transfer."))
            } else if !conflicts.isEmpty {
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "Some names are already taken"),
                    detail: inflected(
                        AttributedString(
                            localized:
                                "^[\(conflicts.count) item](inflect: true) in this transfer share a name with a file here. Keep Both saves the new ones under a new name; Replace overwrites them and resumes partly received files."
                        )))
            }
            // Three labels do not fit side by side at accessibility text sizes
            // on a phone, so they stack there.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.space5) { actions }
                VStack(spacing: Spacing.space3) { actions }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        Button("Decline", role: .destructive) { controller.respond(accept: false) }
            .buttonVariant(.destructive)
            .controlSize(.large)
        if blocked.isEmpty, !conflicts.isEmpty {
            Button("Replace") { controller.respond(accept: true, policy: .replace) }
                .buttonVariant(.secondary)
                .controlSize(.large)
            Button("Keep Both") { controller.respond(accept: true, policy: .keepBoth) }
                .buttonVariant(.prominent)
                .controlSize(.large)
        } else {
            // Until the conflict scan reports, Accept keeps both: it
            // never overwrites a file the scan has not shown yet.
            Button("Accept") { controller.respond(accept: true, policy: .keepBoth) }
                .buttonVariant(.prominent)
                .controlSize(.large)
                .disabled(!blocked.isEmpty)
        }
    }
}
