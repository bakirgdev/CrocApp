import SwiftUI

struct ContentView: View {
    @Environment(TransferController.self) private var controller
    @Environment(LocalNetworkChecker.self) private var localNetwork
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var shareInbox = ShareInbox()
    @State private var showStagedSheet = false
    @AppStorage("onboarding.seen") private var onboardingSeen = false
    @State private var showOnboarding = false
    #if os(macOS)
    @State private var isDropTargeted = false
    #endif

    var body: some View {
        HomeView()
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
            #endif
            .task {
                if AutoVerify.forcesOnboarding || (!onboardingSeen && !AutoVerify.isHarnessRun) {
                    showOnboarding = true
                }
                // Cold launch renders .active with no prior phase, so
                // scenePhase's onChange below (a transition) never fires for
                // it; offer the staged sheet here too, under the same
                // !controller.isActive gating as that handler.
                if !controller.isActive {
                    shareInbox.refresh()
                    showStagedSheet = !shareInbox.staged.isEmpty && !showOnboarding
                }
                await AutoVerify.runIfRequested(controller: controller)
            }
            .onChange(of: controller.isActive) { _, active in
                if active { localNetwork.checkIfNeeded() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { localNetwork.recheckIfDenied() }
                // Gate on !controller.isActive before touching the inbox at
                // all, not just before presenting: refresh() purges batches
                // no manifest points to, and purgeStaleBatches()'s "don't
                // delete the batch behind an active send" guard only works
                // for repeat refreshes on THIS instance (it checks this
                // instance's own `staged` cache). A transfer started
                // elsewhere (e.g. AutoVerify's own short-lived ShareInbox for
                // --auto-share-send) already consumed the manifest by the
                // time it calls startSend, so if this instance's first-ever
                // refresh() lands mid-transfer it has no cached `staged` to
                // protect the batch with and deletes the file out from under
                // croc mid-send. controller.isActive flips true synchronously
                // before any such call returns, so gating here closes the
                // window.
                guard phase == .active, !controller.isActive else { return }
                shareInbox.refresh()
                showStagedSheet = !shareInbox.staged.isEmpty && !showOnboarding
            }
            .sheet(isPresented: $showStagedSheet) {
                StagedFilesSheet(
                    files: shareInbox.staged,
                    send: {
                        let urls = shareInbox.staged
                        shareInbox.consumeManifest()
                        showStagedSheet = false
                        // Navigate to Send first: TransferStatusView only
                        // renders inside SendView/ReceiveView, so without
                        // this the transfer would run invisibly under
                        // HomeView. Mirrors AppDelegate's dock-drop routing.
                        router.path = [.send]
                        controller.startSend(urls: urls, customCode: "")
                    },
                    discard: {
                        shareInbox.consumeManifest()
                        shareInbox.refresh()
                        showStagedSheet = false
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

    #if os(macOS)
    // design/components.md → DropZone: macOS full-window "Drop to send"
    // overlay, scrim background, --radius-2xl (the one place that radius is
    // used) and a glass surface. Not itself a drop target — the window-level
    // dropDestination above owns hover tracking and the actual file filter.
    private var dropOverlay: some View {
        ZStack {
            Color.scrim
            VStack(spacing: Spacing.space4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentTextOnTint)
                    .accessibilityHidden(true)
                Text("Drop to send")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentTextOnTint)
            }
            .padding(Spacing.space9)
            .glassEffect(
                .regular, in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous)
            )
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
        .environment(TransferController(settings: AppSettings()))
        .environment(OutputFolderStore())
        .environment(LocalNetworkChecker())
        .environment(AppRouter.shared)
}
