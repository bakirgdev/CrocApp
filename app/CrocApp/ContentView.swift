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
        }
            #endif
            .task {
                if !onboardingSeen && !AutoVerify.isHarnessRun { showOnboarding = true }
                await AutoVerify.runIfRequested(controller: controller)
            }
            .onChange(of: controller.isActive) { _, active in
                router.isBusy = active
                if active { localNetwork.checkIfNeeded() }
            }
            .onChange(of: scenePhase) { _, phase in
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
                    showStagedSheet = !shareInbox.staged.isEmpty
                }
            ) {
                OnboardingView {
                    showOnboarding = false
                }
            }
    }
}

#Preview {
    ContentView()
        .environment(TransferController(settings: AppSettings()))
        .environment(OutputFolderStore())
        .environment(LocalNetworkChecker())
        .environment(AppRouter.shared)
}
