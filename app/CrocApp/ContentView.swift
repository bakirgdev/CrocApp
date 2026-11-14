import StoreKit
import SwiftUI

struct ContentView: View {
    #if !DIRECT
    @Environment(\.requestReview) private var requestReview
    #endif
    @Environment(TransferController.self) private var controller
    @Environment(LocalNetworkChecker.self) private var localNetwork
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.launchMode) private var launchMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var shareInbox = ShareInbox()
    @State private var showStagedSheet = false
    @AppStorage("onboarding.seen") private var onboardingSeen = false
    @State private var showOnboarding = false
    #if os(macOS)
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // components.md → DropZone: overlay glyph at 44, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var dropGlyphSize: CGFloat = 44
    #endif

    var body: some View {
        layout
            #if os(macOS)
        .dropDestination(for: URL.self) { urls, _ in
            // Anywhere-on-window drop routes to the Send screen; the
            // SendView list's own dropDestination takes precedence when
            // hovering the list itself.
            guard !controller.isActive else { return false }
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            router.openSend(with: files)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
        // The overlay is inserted and removed, so its `.transition` needs an
        // animation context on the container that stays.
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationFast), value: isDropTargeted)
            #endif
            .phoneHaptic(trigger: TransferHaptic(controller.phase)) { _, new in new?.feedback }
            .onChange(of: horizontalSizeClass, initial: true) { _, sizeClass in
                router.isRegularWidth = sizeClass != .compact
            }
            .task {
                if AutoVerify.forcesOnboarding || (!onboardingSeen && launchMode.isLive) {
                    showOnboarding = true
                }
                // Cold launch renders .active with no prior phase, so
                // scenePhase's onChange below (a transition) never fires for
                // it; offer the staged sheet here too, under the same
                // !controller.isActive gating as that handler.
                offerStagedFiles()
                await AutoVerify.runIfRequested(controller: controller)
            }
            .onChange(of: controller.isActive) { _, active in
                if active { localNetwork.checkIfNeeded() }
            }
            .onChange(of: controller.phase) { _, phase in
                // A failed send keeps its shared batch: Try Again reuses the files.
                switch phase {
                case .done, .stored: shareInbox.sendFinished()
                default: break
                }
            }
            // A share that arrived during a transfer, or waits behind the one
            // just sent, is offered once the app is idle again.
            .onChange(of: controller.isActive) { _, active in
                if !active { offerStagedFiles() }
            }
            #if !DIRECT
        // The id is the success count, so this restarts on each success and
        // not at launch (the phase is .idle then). A new transfer or a sheet
        // within the delay cancels or vetoes the request.
        .task(id: controller.settings.successfulTransfers) {
            guard case .done = controller.phase else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, case .done = controller.phase,
                !showStagedSheet, !showOnboarding, scenePhase == .active,
                ReviewPrompt.shouldAsk(
                    successfulTransfers: controller.settings.successfulTransfers,
                    lastPromptedVersion: controller.settings.lastReviewPromptVersion,
                    currentVersion: AppInfo.marketingVersion)
            else { return }
            controller.settings.lastReviewPromptVersion = AppInfo.marketingVersion
            requestReview()
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            // A secret typed a moment ago is still waiting for its Keychain write.
            if phase != .active { controller.settings.flushSecrets() }
            if phase == .active { localNetwork.recheckIfDenied() }
            guard phase == .active else { return }
            offerStagedFiles()
        }
        #if os(macOS)
        // scenePhase stays .active while the window is open, so a share
        // that arrives while the app runs is only seen on activation.
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            offerStagedFiles()
        }
        #endif
        .sheet(isPresented: $showStagedSheet) {
            StagedFilesSheet(
                files: shareInbox.staged,
                // A Shortcut, the menu bar or a drop can start a transfer
                // while the sheet is open; the share then waits, still staged.
                canSend: !controller.isActive,
                send: {
                    guard let batch = shareInbox.batch,
                        controller.start(.sendFiles(urls: shareInbox.staged, code: ""))
                    else { return }
                    shareInbox.consume(batch)
                    showStagedSheet = false
                    // TransferStatusView only renders inside SendView and
                    // ReceiveView, so without this the transfer would run
                    // invisibly under HomeView. Mirrors AppDelegate's
                    // dock-drop routing.
                    router.path = [.send]
                },
                discard: {
                    if let batch = shareInbox.batch { shareInbox.discard(batch) }
                    // Shows the next waiting share, or closes the sheet.
                    offerStagedFiles()
                })
        }
        .sheet(
            isPresented: $showOnboarding,
            onDismiss: {
                onboardingSeen = true
                // The staged sheet yields to onboarding on first launch;
                // offer it now instead of waiting for the next foreground.
                // Guarded the same way as the scenePhase and .task offers,
                // for symmetry with them.
                showStagedSheet = !shareInbox.staged.isEmpty && !controller.isActive
                // Sequenced, not simultaneous: two stacked system prompts
                // on first launch is bad UX.
                #if os(iOS)
                Task {
                    await CameraPermission.requestIfNeeded()
                    localNetwork.checkIfNeeded()
                }
                #endif
            },
            content: {
                OnboardingView {
                    showOnboarding = false
                }
            }
        )
    }

    /// design/principles.md → Platform adaptation: compact is Home and one stack,
    /// anything else the sidebar. SwiftUI reports `.regular` on macOS, where
    /// every window gets the sidebar.
    @ViewBuilder private var layout: some View {
        if horizontalSizeClass == .compact {
            HomeView()
        } else {
            RegularLayout()
        }
    }

    private func offerStagedFiles() {
        // Gate on !controller.isActive before touching the inbox at
        // all, not just before presenting: refresh() purges batches
        // without a manifest, and purgeAndListPending()'s "don't
        // delete the batch behind an active send" guard only works
        // for refreshes on THIS instance (it checks `sendingBatch`,
        // which is per instance). A transfer started
        // elsewhere (e.g. AutoVerify's own short-lived ShareInbox for
        // --auto-share-send) already consumed the manifest by the
        // time it calls start, so if this instance's first-ever
        // refresh() lands mid-transfer it has no cached `staged` to
        // protect the batch with and deletes the file out from under
        // croc mid-send. controller.isActive flips true synchronously
        // before any such call returns, so gating here closes the
        // window.
        guard !controller.isActive else { return }
        shareInbox.refresh()
        // Shared text needs no sheet: the Send screen is where it waits for
        // the user's Send, like a Services-menu selection.
        if let text = shareInbox.text, let batch = shareInbox.batch {
            shareInbox.discard(batch)
            shareInbox.refresh()
            router.openSend(text: text)
        }
        showStagedSheet = !shareInbox.staged.isEmpty && !showOnboarding
    }

    #if os(macOS)
    // design/components.md → DropZone: macOS full-window overlay, scrim
    // background and a glass card at --radius-2xl. Not itself a drop target:
    // the window-level dropDestination above owns hover tracking and the
    // actual file filter.
    private var dropOverlay: some View {
        ZStack {
            Color.scrim
            VStack(spacing: Spacing.space4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: dropGlyphSize))
                    .foregroundStyle(Color.accentTextOnTint)
                    .accessibilityHidden(true)
                Text("Drop to Send")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentTextOnTint)
            }
            .padding(Spacing.space9)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.xxl, style: .continuous))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .transition(.opacity)
        .accessibilityHidden(true)
    }
    #endif
}

#Preview {
    ContentView()
        .environment(
            TransferController(
                settings: AppSettings(), vault: StoredTransferVault(secrets: MemorySecretStore()))
        )
        .environment(OutputFolderStore())
        .environment(LocalNetworkChecker())
        .environment(AppRouter.shared)
}
