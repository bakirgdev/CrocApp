import CrocKit
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Reads the controller's progress tick itself, so a tick (10 Hz) redraws only
/// `content` and not the view that places it.
struct ProgressTick<Content: View>: View {
    @Environment(TransferController.self) private var controller
    @ViewBuilder let content: (TransferProgress) -> Content

    var body: some View {
        if let progress = controller.progress { content(progress) }
    }
}

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // A received text scrolls inside this height, scaled with Dynamic Type.
    @ScaledMetric private var receivedTextMaxHeight: CGFloat = 200

    // Long enough that ordinary relay/handshake latency doesn't false-positive,
    // short enough to reassure before the user assumes the app is hung.
    private static let slowPhaseThreshold: Duration = .seconds(25)

    private var isInEarlyPhase: Bool {
        switch controller.phase {
        case .starting, .connecting: true
        default: false
        }
    }

    /// The cross-fade keys on this, not on every progress tick
    /// (design/principles.md → Motion).
    private var phaseKind: TransferController.Phase.Kind { controller.phase.kind }

    private var showsHeader: Bool {
        switch phaseKind {
        case .idle, .done, .stored, .failed: false
        default: true
        }
    }

    var body: some View {
        Group {
            // The link result is a screen of its own: its Revoke and Done act on
            // state it keeps.
            if case .stored(let receipt) = controller.phase {
                StoredLinkView(receipt: receipt)
            } else {
                ActionScreen {
                    content
                } actions: {
                    actions
                }
            }
        }
        .animation(phaseAnimation, value: phaseKind == .stored)
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

    // A running transfer reads down from its header, so nothing above the header
    // or the code phrase ever changes and none of them moves (principles.md →
    // Motion).
    private var content: some View {
        VStack(spacing: 24) {
            if showsHeader {
                header.transition(.opacity)
            }

            // The waiting phase keeps the banner under its code phrase.
            if phaseKind != .waiting {
                localNetworkDeniedBanner
            }

            // One cross-fade on the block that swaps; its contents do not
            // animate in separately. The ZStack lets old and new overlap
            // instead of stacking while both are in the tree, so the new phase
            // does not shift once the old one is gone.
            ZStack(alignment: .top) {
                phaseContent
                    .id(phaseKind)
                    .transition(.opacity)
            }
            .animation(phaseAnimation, value: phaseKind)
        }
        .animation(phaseAnimation, value: showsHeader)
        .animation(phaseAnimation, value: localNetworkDenied)
    }

    /// The buttons of the phase, in the actions row: the prominent one last.
    @ViewBuilder private var actions: some View {
        switch controller.phase {
        case .incoming(_, let conflicts, let blocked):
            incomingActions(conflicts: conflicts, blocked: blocked)
        case .done:
            doneActions
        case .failed(let failure):
            failedActions(failure)
        case .confirmSend:
            cancelAction
            resultAction("Send") { controller.respond(accept: true) }
        default:
            if controller.phase.canCancel { cancelAction }
        }
    }

    private var cancelAction: some View {
        destructiveAction("Cancel") { controller.cancel() }
            .keyboardShortcut(.cancelAction)
    }

    private var localNetworkDenied: Bool { localNetwork.status == .denied }

    private var phaseAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    /// The direction header, which persists from the start of a transfer to its
    /// result (principles.md → Motion).
    private var header: some View {
        VStack(spacing: 16) {
            DirectionHeader(direction: controller.direction, pulses: phaseKind == .waiting)
            // A stored transfer meets no relay, so only its send says where the
            // files are held; a stored receive says nothing.
            if controller.isStoredTransfer, controller.direction == .send {
                Text("Encrypted on this device. The link server only holds the encrypted files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var phaseContent: some View {
        switch controller.phase {
        case .idle, .stored:
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
            ProgressTick { progress in
                if progress.isBundling { bundleView(progress) } else { transferringView(progress) }
            }
        case .done(let summary, let receivedText):
            doneView(summary, receivedText: receivedText)
        case .failed(let failure):
            StatusBlock(failure: failure)
        }
    }

    private func earlyPhase(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: 24) {
            ProgressView().accessibilityHidden(true)
            Text(title).foregroundStyle(.secondary)
            // Fades in late so it reads as information, not alarm.
            ZStack {
                if showsSlowPhaseHint {
                    slowPhaseHintText.transition(.opacity)
                }
            }
            .animation(
                reduceMotion ? nil : .default, value: showsSlowPhaseHint)
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

    // MARK: - Local network denied

    // The two platforms spell the same pane differently, and naming the wrong
    // one is worse than naming none.
    #if os(iOS)
    static let localNetworkDeniedDetail = String(
        localized:
            "Transfers use the relay only. Enable it in Settings › Privacy & Security › Local Network for faster direct transfers.",
        comment: "The path names the iOS Settings app. Match its translated pane names.")
    #else
    static let localNetworkDeniedDetail = String(
        localized:
            "Transfers use the relay only. Enable it in System Settings › Privacy & Security › Local Network for faster direct transfers.",
        comment: "The path names the macOS System Settings app. Match its translated pane names."
    )
    #endif

    // Local-network-denied is `info`, not a warning. The relay path still works, this is a "could be faster"
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
            .transition(.opacity)
        }
    }

    /// Opens where the fix lives: CrocApp's own
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
            router.showSettings(advanced: place == .advanced)
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
        VStack(spacing: 16) {
            CodePhraseDisplay(code: code)
            localNetworkDeniedBanner
            let webURL = TransferLink.webURL(forCode: code)
            QRCodeView(content: webURL?.absoluteString ?? code)
            if let webURL {
                ShareLink(item: webURL) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)
                .touchTargets()
            }
            Text("On the other device, enter this code or scan the QR.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let note = browserReceiveNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            // The header's pulsing arrow says the app is alive (principles.md →
            // Motion); this says what it waits for.
            Text("Waiting for the other device…")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("The other device is connected").font(.headline)
            Text("Send the selected items to the connected device?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Incoming (accept gate)

    @ViewBuilder private func incomingActions(conflicts: [String], blocked: [String]) -> some View {
        destructiveAction("Decline") { controller.respond(accept: false) }
        if blocked.isEmpty, !conflicts.isEmpty {
            resultAction("Replace", prominent: false) {
                controller.respond(accept: true, policy: .replace)
            }
            resultAction("Keep Both") { controller.respond(accept: true, policy: .keepBoth) }
        } else {
            // Until the conflict scan reports, Accept keeps both: it
            // never overwrites a file the scan has not shown yet.
            resultAction("Accept") { controller.respond(accept: true, policy: .keepBoth) }
                .disabled(!blocked.isEmpty)
        }
    }

    // MARK: - Transferring

    private func transferringView(_ p: TransferProgress) -> some View {
        let fileFraction = fraction(p.fileSent, of: p.fileSize)
        let totalDone = p.bytesDone
        let totalFraction = fraction(totalDone, of: p.totalSize)
        let fileNumber = min(p.currentFile + 1, p.totalFiles)
        return VStack(spacing: 16) {
            VStack(alignment: .leading) {
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
                labelAndValue {
                    // Hidden until the engine reports a count: "File 0 of 0" is wrong.
                    if p.totalFiles > 0 {
                        Text("File \(fileNumber) of \(p.totalFiles)")
                            .contentTransition(numericTransition)
                            .animation(phaseAnimation, value: fileNumber)
                    }
                } value: {
                    Text(
                        // spellsOutZero: the default renders the first moments
                        // of every transfer as "Zero kB / 41 MB".
                        verbatim:
                            "\(p.fileSent.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.fileSize.formatted(.byteCount(style: .file)))"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(percent(fileFraction))
            VStack(alignment: .leading) {
                ForwardProgressBar(
                    fraction: totalFraction, resetKey: ProgressScope(file: -1, size: p.totalSize)
                )
                .accessibilityLabel("Overall progress")
                labelAndValue {
                    Text(
                        "Total \(totalDone.formatted(.byteCount(style: .file, spellsOutZero: false))) / \(p.totalSize.formatted(.byteCount(style: .file)))"
                    )
                    .foregroundStyle(.secondary)
                } value: {
                    SpeedText(reduceMotion: reduceMotion)
                }
                .font(.caption)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(percent(totalFraction))
        }
    }

    /// croc moves a run of small files as one batch and counts none of its
    /// bytes where the engine can read them, so the extent is unknown and the
    /// bar indeterminate.
    private func bundleView(_ p: TransferProgress) -> some View {
        VStack(alignment: .leading) {
            #if os(macOS)
            Text("A batch of small files")
                .font(.callout)
            ProgressView()
                .progressViewStyle(.linear)
                .accessibilityLabel("Overall progress")
            #else
            // iOS draws an indeterminate linear ProgressView as a still, empty
            // track, which reads as stuck at 0%; a spinner shows it is moving.
            HStack {
                ProgressView()
                    .accessibilityLabel("Overall progress")
                Text("A batch of small files")
            }
            .font(.callout)
            #endif
            labelAndValue {
                Text("^[\(p.totalFiles) file](inflect: true)")
            } value: {
                Text(verbatim: p.totalSize.formatted(.byteCount(style: .file)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    /// A label and its value side by side, or the label above the value at
    /// accessibility text sizes, where a byte count would otherwise truncate.
    private func labelAndValue(
        @ViewBuilder label: () -> some View, @ViewBuilder value: () -> some View
    ) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())
        return layout {
            label()
            value().frame(maxWidth: .infinity, alignment: stacked ? .leading : .trailing)
        }
    }

    /// Digits swap instantly under Reduce Motion.
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
        VStack(spacing: 16) {
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
        }
    }

    @ViewBuilder private var doneActions: some View {
        if controller.direction == .receive, let folder = controller.lastOutputFolder {
            folderButton(folder)
        }
        resultAction("Done") { controller.reset() }
    }

    /// The selectable text and its two actions (docs/knowledge/app-ui-architecture.md →
    /// System surfaces: a text payload is not a row).
    private func receivedTextBlock(_ text: String) -> some View {
        VStack(spacing: 16) {
            ScrollView {
                Text(text)
                    .font(.body.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: receivedTextMaxHeight)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { receivedTextActions(text) }
                VStack { receivedTextActions(text) }
            }
        }
    }

    @ViewBuilder private func receivedTextActions(_ text: String) -> some View {
        CopyButton("Copy Text") { Clipboard.copy(text) }
        ShareLink(item: text) {
            Label("Share Text", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.glass)
        .touchTargets()
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
            resultAction(prominent: false) {
                openInFiles(folder)
            } label: {
                Label("Open in Files", systemImage: "folder")
            }
        }
        #else
        resultAction(prominent: false) {
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

    /// components.md → StatusBlock: Done always, plus the one action that could
    /// help, if any.
    @ViewBuilder private func failedActions(_ failure: TransferFailure) -> some View {
        switch failure.remedy {
        case .tryAgain?:
            resultAction("Done", prominent: false) { controller.reset() }
            resultAction("Try Again") { controller.retry() }
        case .openSettings(let place)?:
            resultAction("Done", prominent: false) { controller.reset() }
            resultAction("Open Settings") { open(place) }
        case nil:
            resultAction("Done") { controller.reset() }
        }
    }
}

extension View {
    /// 44 pt targets on iOS, where `.controlSize(.large)` is what gives them
    /// (design/principles.md); macOS keeps its natural sizes.
    func touchTargets() -> some View {
        #if os(iOS)
        controlSize(.large)
        #else
        self
        #endif
    }
}

/// The live speed, refreshed at most once a second (principles.md → Motion: a roll
/// that restarts five times a second reads as a blur). It
/// samples the controller on its own clock instead of observing it, so a
/// progress tick does not redraw it.
private struct SpeedText: View {
    @Environment(TransferController.self) private var controller
    let reduceMotion: Bool
    @State private var bytesPerSecond: Double = 0

    var body: some View {
        Text(text)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(
                reduceMotion ? nil : .default, value: bytesPerSecond
            )
            .task {
                while !Task.isCancelled {
                    bytesPerSecond = controller.speedBytesPerSec
                    try? await Task.sleep(for: .seconds(1))
                }
            }
    }

    /// An unknown or zero speed is an em dash, never "0 B/s": a zero reads as
    /// a stall (voice.md → Numbers).
    private var text: String {
        guard bytesPerSecond > 0 else { return "—" }
        let size = Int64(bytesPerSecond).formatted(.byteCount(style: .file))
        return String(
            localized: "\(size)/s",
            comment: "A transfer speed: a file size, such as 3.2 MB, per second.")
    }
}
