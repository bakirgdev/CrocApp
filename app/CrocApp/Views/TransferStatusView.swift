import Accessibility
import CrocKit
import QuickLook
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
    // components.md → FileRow, Received: a received text scrolls inside
    // this height, scaled with Dynamic Type.
    @ScaledMetric private var receivedTextMaxHeight: CGFloat = 200

    // Long enough that ordinary relay/handshake latency doesn't false-positive,
    // short enough to reassure before the user assumes the app is hung.
    private static let slowPhaseThreshold: Duration = .seconds(25)

    /// components.md → FileRow: a list of rows (the accept gate, the received
    /// files) scrolls inside this height, scaled with Dynamic Type.
    fileprivate static let fileListMaxHeight: CGFloat = 240

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

    /// A running transfer shows the direction header and the trust badge on
    /// top; a result does not.
    private var showsHeader: Bool {
        switch phaseKind {
        case .idle, .done, .stored, .failed: false
        default: true
        }
    }

    var body: some View {
        // The phase content scrolls when taller than the screen (accessibility
        // text sizes) and fits the screen otherwise. Not ViewThatFits: it
        // measures the unwrapped ideal height, so wrapping text (link, callout)
        // made it pick the plain branch and clip the bottom of the screen.
        GeometryReader { proxy in
            ScrollView {
                // fixedSize: minHeight proposes the screen height down to the
                // content, which would squeeze wrapping text into ellipses.
                // A running transfer reads down from its header, so nothing
                // above the header, the badge or the code phrase ever changes
                // and none of them moves (motion.md → Choreography, rule 2).
                // A result sits in the middle.
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity, minHeight: proxy.size.height,
                        alignment: showsHeader ? .top : .center)
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
            if showsHeader {
                header.transition(.opacity)
            }

            // The waiting phase keeps the banner under its code phrase.
            if phaseKind != .waiting {
                localNetworkDeniedBanner
            }

            // One cross-fade on the block that swaps; its contents do not
            // animate in separately. The ZStack lets old and new overlap
            // instead of stacking while both are in the tree, aligned the
            // way the screen is, so the new phase does not shift once the
            // old one is gone.
            ZStack(alignment: showsHeader ? .top : .center) {
                phaseContent
                    .id(phaseKind)
                    .transition(.opacity)
            }
            .animation(phaseAnimation, value: phaseKind)

            if showsCancel {
                Button("Cancel", role: .destructive) { controller.cancel() }
                    .buttonVariant(.destructiveTinted)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .animation(phaseAnimation, value: showsHeader)
        .animation(phaseAnimation, value: localNetworkDenied)
    }

    private var localNetworkDenied: Bool { localNetwork.status == .denied }

    private var phaseAnimation: Animation? {
        reduceMotion ? nil : Motion.easeOut(Motion.durationBase)
    }

    /// The direction header and the trust badge, which persist from the start
    /// of a transfer to its result (motion.md → Choreography, rule 2).
    private var header: some View {
        VStack(spacing: Spacing.space5) {
            DirectionHeader(direction: controller.direction, pulses: phaseKind == .waiting)
            if controller.isStoredTransfer {
                // A stored transfer meets no relay, so the relay badge would
                // describe a path it does not take. The caption speaks for a
                // send; a stored receive gets neither.
                if controller.direction == .send {
                    Text(
                        "Encrypted on this device. The link server only holds the encrypted files."
                    )
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                }
            } else {
                TrustBadge(relay: controller.activeRelay)
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
            StoredLinkView(receipt: receipt)
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
    @ViewBuilder private var localNetworkDeniedBanner: some View {
        if localNetworkDenied {
            StatusBanner(
                kind: .info,
                title: String(localized: "Local network access is off"),
                detail: Self.localNetworkDeniedDetail,
                actionTitle: "Open Settings",
                action: { open(.localNetworkAccess) }
            )
            .transition(.statusBannerInsert(reduceMotion: reduceMotion))
        }
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
            router.path.append(
                contentsOf: place == .advanced ? [.settings, .advancedSettings] : [.settings])
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
            localNetworkDeniedBanner
            let webURL = TransferLink.webURL(forCode: code)
            QRCodeView(content: webURL?.absoluteString ?? code)
            if let webURL {
                ShareLink(item: webURL) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
                .buttonVariant(.secondary)
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
            // The header's pulsing arrow says the app is alive (motion.md →
            // Vocabulary, Pulse); this says what it waits for.
            Text("Waiting for the other device…")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
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
            HStack(spacing: Spacing.space5) {
                Button("Cancel", role: .destructive) { controller.cancel() }
                    .buttonVariant(.destructiveTinted)
                    .keyboardShortcut(.cancelAction)
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
        let fileNumber = min(p.currentFile + 1, p.totalFiles)
        return VStack(spacing: Spacing.space5) {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                // The sender's name until the transfer is cancelled, which an
                // auto-accepted blocked name can reach first.
                Text(ReceivedName.shown(p.fileName))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForwardProgressBar(
                    fraction: fileFraction,
                    resetKey: ProgressScope(file: p.currentFile, size: p.fileSize)
                )
                .accessibilityLabel("Current file progress")
                HStack {
                    Text("File \(fileNumber) of \(p.totalFiles)")
                        .contentTransition(numericTransition)
                        .animation(phaseAnimation, value: fileNumber)
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
                    SpeedText(reduceMotion: reduceMotion)
                }
                .font(.caption)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(percent(totalFraction))
        }
    }

    /// motion.md → Vocabulary, Numeric text; digits swap instantly under
    /// Reduce Motion.
    private var numericTransition: ContentTransition {
        reduceMotion ? .identity : .numericText()
    }

    /// What a progress bar measures. A new scope snaps the bar instead of
    /// letting it run backwards.
    private struct ProgressScope: Hashable {
        let file: Int
        let size: Int64
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
                summary: summary, receivedText: receivedText, direction: controller.direction)
            if let receivedText {
                receivedTextBlock(receivedText)
            } else if controller.direction == .receive, let folder = controller.lastOutputFolder {
                ReceivedFilesList(
                    folder: folder, names: controller.offeredFileNames,
                    since: controller.startedAt ?? .distantPast,
                    isScoped: outputFolder.isUserSelected, reveal: reveal(in: folder))
            }
            VStack(spacing: Spacing.space3) {
                if controller.direction == .receive, let folder = controller.lastOutputFolder {
                    folderButton(folder)
                }
                resultAction("Done") { controller.reset() }
            }
        }
    }

    /// The selectable text and its two actions (platforms.md → Received
    /// files: a text payload is not a row).
    private func receivedTextBlock(_ text: String) -> some View {
        VStack(spacing: Spacing.space5) {
            ScrollView {
                Text(text)
                    .font(.body.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: receivedTextMaxHeight)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.space5) { receivedTextActions(text) }
                VStack(spacing: Spacing.space3) { receivedTextActions(text) }
            }
        }
    }

    @ViewBuilder private func receivedTextActions(_ text: String) -> some View {
        CopyButton("Copy Text") { Clipboard.copy(text) }
        ShareLink(item: text) {
            Label("Share Text", systemImage: "square.and.arrow.up")
        }
        .buttonVariant(.secondary)
    }

    /// Shows a received item where it was saved. iOS can only show the app's
    /// own default folder (see the folder button), so elsewhere there is none.
    private func reveal(in folder: URL) -> ((URL) -> Void)? {
        #if os(iOS)
        guard isDefaultOutputFolder(folder) else { return nil }
        return { _ in openInFiles(folder) }
        #else
        return { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
        #endif
    }

    @ViewBuilder private func folderButton(_ folder: URL) -> some View {
        #if os(iOS)
        // shareddocuments:// only resolves paths inside the app's own
        // container -- a fileImporter-picked iCloud Drive or other
        // provider folder isn't reachable through it, so only offer
        // the button when the folder is still our own default.
        if isDefaultOutputFolder(folder) {
            resultAction(variant: .secondary) {
                openInFiles(folder)
            } label: {
                Label("Open in Files", systemImage: "folder")
            }
        }
        #else
        resultAction(variant: .secondary) {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        #endif
    }

    #if os(iOS)
    private func openInFiles(_ folder: URL) {
        let target = "shareddocuments://" + folder.path(percentEncoded: true)
        if let url = URL(string: target) {
            UIApplication.shared.open(url)
        }
    }
    #endif

    private func failedView(_ failure: TransferFailure) -> some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(failure: failure)
            // components.md → StatusBlock: Done always, plus the one action
            // that could help, if any.
            VStack(spacing: Spacing.space3) {
                switch failure.remedy {
                case .tryAgain?:
                    resultAction("Try Again") { controller.retry() }
                    resultAction("Done", variant: .secondary) { controller.reset() }
                case .openSettings(let place)?:
                    resultAction("Open Settings") { open(place) }
                    resultAction("Done", variant: .secondary) { controller.reset() }
                case nil:
                    resultAction("Done") { controller.reset() }
                }
            }
        }
    }
}

/// A StatusBlock action: large and full width (components.md → StatusBlock).
private func resultAction(
    _ title: LocalizedStringKey, variant: ButtonVariant = .prominent,
    action: @escaping () -> Void
) -> some View {
    resultAction(variant: variant, action: action) { Text(title) }
}

private func resultAction(
    variant: ButtonVariant, action: @escaping () -> Void,
    @ViewBuilder label: () -> some View
) -> some View {
    Button(action: action) {
        label().frame(maxWidth: .infinity)
    }
    .buttonVariant(variant)
    .controlSize(.large)
}

/// The live speed, refreshed at most once a second (motion.md → Vocabulary,
/// rule 3: a roll that restarts five times a second reads as a blur). It
/// samples the controller on its own clock instead of observing it, so a
/// progress tick does not redraw it.
private struct SpeedText: View {
    @Environment(TransferController.self) private var controller
    let reduceMotion: Bool
    @State private var bytesPerSecond: Double = 0

    var body: some View {
        Text(text)
            .fontWeight(.medium)
            .foregroundStyle(Color.textPrimary)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(
                reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: bytesPerSecond)
            .task {
                while !Task.isCancelled {
                    bytesPerSecond = controller.speedBytesPerSec
                    try? await Task.sleep(for: .seconds(1))
                }
            }
    }

    /// An unknown or zero speed is an em dash, never "0 B/s": a zero reads as
    /// a stall (content.md → Numbers).
    private var text: String {
        guard bytesPerSecond > 0 else { return "—" }
        return "\(Int64(bytesPerSecond).formatted(.byteCount(style: .file)))/s"
    }
}

/// What a completed receive wrote, as `FileRow`s (platforms.md → Received
/// files). Quick Look previews a file; the app never opens one itself.
private struct ReceivedFilesList: View {
    let folder: URL
    let names: [String]
    let since: Date
    /// A folder the user picked: reading it, and previewing from it, needs
    /// its security scope, which the controller let go at the end.
    let isScoped: Bool
    let reveal: ((URL) -> Void)?

    @State private var items: [ReceivedItem] = []
    @State private var preview: URL?
    @State private var holdsScope = false
    @ScaledMetric private var listMaxHeight = TransferStatusView.fileListMaxHeight

    var body: some View {
        ZStack {
            if !items.isEmpty {
                ScrollView {
                    // A card of rows: FileRow draws the first/last corner
                    // rounding and the separators.
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            FileRow(
                                received: item, isFirst: index == 0,
                                isLast: index == items.count - 1,
                                quickLook: { preview = item.url },
                                reveal: reveal.map { reveal in { reveal(item.url) } })
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: listMaxHeight)
            }
        }
        .quickLookPreview($preview, in: items.filter { !$0.isFolder }.map(\.url))
        .task(id: folder) {
            if isScoped, !holdsScope {
                holdsScope = folder.startAccessingSecurityScopedResource()
            }
            let names = names
            let folder = folder
            let since = since
            items = await Task.detached(priority: .userInitiated) {
                ReceivedItems.locate(names: names, in: folder, since: since)
            }.value
        }
        .onDisappear {
            guard holdsScope else { return }
            folder.stopAccessingSecurityScopedResource()
            holdsScope = false
        }
    }
}

/// The result of a Send as Link: the link, its QR, Copy and Share, and Revoke
/// (components.md → StatusBlock). Revoke is here for every link, so one sent
/// with Save Transfer History off, which History never lists, can be revoked.
private struct StoredLinkView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let receipt: StoredReceipt

    @State private var confirmsRevoke = false
    @State private var isRevoking = false
    @State private var revoked = false
    @State private var revokeFailure: String?

    var body: some View {
        ZStack {
            if revoked {
                VStack(spacing: Spacing.space5) {
                    StatusBlock(
                        kind: .neutral, title: String(localized: "Link revoked"),
                        detail: String(localized: "It no longer works for anyone."))
                    resultAction("Done") { controller.reset() }
                }
                .transition(.opacity)
            } else {
                ready.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: revoked)
        .confirmationDialog("Revoke this link?", isPresented: $confirmsRevoke) {
            Button("Revoke Link", role: .destructive) { revoke() }
        } message: {
            Text(
                "The files are deleted from the link server and the link stops working for everyone."
            )
        }
        .alert("Couldn't revoke the link", isPresented: revokeFailureShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(revokeFailure ?? "")
        }
    }

    private var ready: some View {
        VStack(spacing: Spacing.space5) {
            StatusBlock(receipt: receipt)
            QRCodeView(content: receipt.link, label: "QR code for the link")
            Text(receipt.link)
                .font(.caption.monospaced())
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityLabel("Link")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.space5) { linkActions }
                VStack(spacing: Spacing.space3) { linkActions }
            }
            if !controller.storedReceiptSaved {
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "Revoke works only until CrocApp quits"),
                    detail: String(
                        localized:
                            "This device couldn't save the link to the Keychain, so revoke it before you quit if you want it ended early."
                    ))
            }
            Text(revokeNote)
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Spacing.space3) {
                resultAction(variant: .destructiveTinted) {
                    confirmsRevoke = true
                } label: {
                    // components.md → States, loading: the label stays, the
                    // spinner takes the glyph's place.
                    Label {
                        Text("Revoke Link")
                    } icon: {
                        if isRevoking { ProgressView().controlSize(.small) }
                    }
                }
                .disabled(isRevoking)
                resultAction("Done") { controller.reset() }
            }
        }
    }

    @ViewBuilder private var linkActions: some View {
        CopyButton("Copy Link") { Clipboard.copySecret(receipt.link, thisDeviceOnly: true) }
        if let url = URL(string: receipt.link) {
            ShareLink(item: url) {
                Label("Share Link", systemImage: "square.and.arrow.up")
            }
            .buttonVariant(.secondary)
        }
    }

    /// History lists the link only while Save Transfer History is on.
    private var revokeNote: LocalizedStringKey {
        controller.settings.saveTransferHistory
            ? "Anyone who gets this link can download the files until it expires or runs out. You can also revoke it later in History."
            : "Anyone who gets this link can download the files until it expires or runs out. With Save Transfer History off, this screen is the only place to revoke it."
    }

    private var revokeFailureShown: Binding<Bool> {
        Binding(get: { revokeFailure != nil }, set: { if !$0 { revokeFailure = nil } })
    }

    private func revoke() {
        isRevoking = true
        Task {
            defer { isRevoking = false }
            do {
                try await controller.revoke(receipt)
                revoked = true
            } catch let failure as EngineFailure {
                revokeFailure = TransferFailure(failure, situation: .init(isStored: true)).text
            } catch {
                revokeFailure = String(localized: "Try again in a moment.")
            }
        }
    }
}

/// The accept gate. design/components.md → AcceptGate: a phase of the transfer
/// screen, not a sheet or an alert. Decline says no to the other device, Accept
/// (or Keep Both and Replace when a name is taken) says yes. Leaving answers
/// nothing, and there is no Cancel here. The direction header and the trust
/// badge sit above it, in the screen's header.
struct IncomingRequestView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let list: FileList
    let conflicts: [String]
    let blocked: [String]
    @ScaledMetric private var listMaxHeight = TransferStatusView.fileListMaxHeight

    private var summary: String {
        inflected(
            AttributedString(
                localized:
                    "^[\(list.files.count) file](inflect: true) • \(list.totalSize.formatted(.byteCount(style: .file)))"
            ))
    }

    var body: some View {
        VStack(spacing: Spacing.space5) {
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
            Text(summary)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
            if !blocked.isEmpty {
                StatusBanner(
                    kind: .error,
                    title: String(localized: "Blocked: unsafe file names in this transfer."))
            } else if !conflicts.isEmpty {
                // The conflict scan reports after the gate is up, so this
                // banner arrives on its own.
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "Some names are already taken"),
                    detail: inflected(
                        AttributedString(
                            localized:
                                "^[\(conflicts.count) item](inflect: true) in this transfer share a name with a file here. Keep Both saves the new ones under a new name; Replace overwrites them and resumes partly received files."
                        ))
                )
                .transition(.statusBannerInsert(reduceMotion: reduceMotion))
            }
            // Three labels do not fit side by side at accessibility text sizes
            // on a phone, so they stack there.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.space5) { actions }
                VStack(spacing: Spacing.space3) { actions }
            }
        }
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: conflicts.isEmpty)
        // A phase change moves no VoiceOver focus, so say what arrived
        // (accessibility.md → Announcements). Low priority queues it behind
        // the blocked banner's own announcement instead of cutting it off.
        .onAppear {
            var message = AttributedString(
                String(localized: "Files are waiting for your answer") + ". " + summary)
            message.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(message).post()
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
