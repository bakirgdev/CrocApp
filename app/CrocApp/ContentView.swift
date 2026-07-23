import SwiftUI

struct ContentView: View {
    @State private var controller = TransferController()
    @State private var outputFolder = OutputFolderStore()
    @State private var localNetwork = LocalNetworkChecker()

    var body: some View {
        HomeView()
            .environment(controller)
            .environment(outputFolder)
            .environment(localNetwork)
            .task { await AutoVerify.runIfRequested(controller: controller) }
            .onChange(of: controller.isActive) { _, active in
                if active { localNetwork.checkIfNeeded() }
            }
    }
}

#Preview { ContentView() }
