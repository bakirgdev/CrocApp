import SwiftUI

struct ContentView: View {
    @State private var controller = TransferController()
    @State private var outputFolder = OutputFolderStore()

    var body: some View {
        HomeView()
            .environment(controller)
            .environment(outputFolder)
            .task { await AutoVerify.runIfRequested(controller: controller) }
    }
}

#Preview { ContentView() }
