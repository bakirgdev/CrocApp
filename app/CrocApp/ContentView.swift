import SwiftUI

struct ContentView: View {
    @State private var controller = TransferController()
    @State private var outputFolder = OutputFolderStore()
    @State private var localNetwork = LocalNetworkChecker()
    @Environment(\.scenePhase) private var scenePhase
    @State private var shareInbox = ShareInbox()
    @State private var showStagedSheet = false

    var body: some View {
        HomeView()
            .environment(controller)
            .environment(outputFolder)
            .environment(localNetwork)
            .task { await AutoVerify.runIfRequested(controller: controller) }
            .onChange(of: controller.isActive) { _, active in
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
                showStagedSheet = !shareInbox.staged.isEmpty
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
    }
}

#Preview { ContentView() }
