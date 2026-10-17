import SwiftUI

struct StagedFilesSheet: View {
    let files: [URL]
    let send: () -> Void
    let discard: () -> Void

    var body: some View {
        NavigationStack {
            List(files, id: \.self) { url in
                Label(url.lastPathComponent, systemImage: "doc")
            }
            .navigationTitle("Shared Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { discard() }
                        .buttonVariant(.destructiveTinted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                }
            }
        }
    }
}
