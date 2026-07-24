import SwiftUI

struct ShareStagingView: View {
    let items: [NSExtensionItem]
    let complete: () -> Void
    let cancel: (Error) -> Void

    private enum StageState {
        case staging
        case done(count: Int)
        case failed(String)
    }
    @State private var state: StageState = .staging

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .staging:
                    ProgressView("Preparing files…")
                case .done(let count):
                    ContentUnavailableView {
                        Label("Ready to send", systemImage: "checkmark.circle")
                    } description: {
                        Text(
                            "^[\(count) file](inflect: true) staged. Open CrocApp to start the transfer."
                        )
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't prepare files", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Send with CrocApp")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { complete() }
                        .disabled({ if case .staging = state { true } else { false } }())
                }
            }
        }
        .task {
            do {
                let manifest = try await ShareStager.stage(items: items)
                state = .done(count: manifest.files.count)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
