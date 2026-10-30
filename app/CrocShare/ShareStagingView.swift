import SwiftUI

struct ShareStagingView: View {
    let items: [NSExtensionItem]
    let complete: () -> Void
    let cancel: (Error) -> Void

    private enum StageState {
        case staging
        case done(count: Int)
        case failed(Error)
    }
    @State private var state: StageState = .staging

    var body: some View {
        #if os(macOS)
        // A success has nothing to confirm: the controller opens the app.
        VStack(spacing: 16) {
            content
            if case .failed(let error) = state {
                Button("Done") { cancel(error) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 140)
        .task(stage)
        #else
        NavigationStack {
            content
                .navigationTitle("Send with CrocApp")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if case .failed(let error) = state {
                                cancel(error)
                            } else {
                                complete()
                            }
                        }
                        .disabled({ if case .staging = state { true } else { false } }())
                    }
                }
        }
        .task(stage)
        #endif
    }

    @ViewBuilder private var content: some View {
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
        case .failed(let error):
            ContentUnavailableView {
                Label("Couldn't prepare files", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error.localizedDescription)
            }
        }
    }

    private func stage() async {
        do {
            let manifest = try await ShareStager.stage(items: items)
            state = .done(count: manifest.files.count)
            #if os(macOS)
            complete()
            #endif
        } catch {
            state = .failed(error)
        }
    }
}
