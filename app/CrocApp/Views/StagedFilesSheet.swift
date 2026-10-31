import SwiftUI

/// What the share extension handed over, for a yes or no before it is sent.
/// The rows are display only: Discard is the way to drop files from it.
struct StagedFilesSheet: View {
    let files: [URL]
    let send: () -> Void
    let discard: () -> Void

    // Folders are walked off the main thread, once per list, not in `body`.
    @State private var sizes: [URL: Int64] = [:]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(files.enumerated()), id: \.element) { index, url in
                    FileRow(
                        name: url.lastPathComponent,
                        size: sizes[url] ?? 0,
                        isFirst: index == 0,
                        isLast: index == files.count - 1
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: 0, leading: Spacing.space5, bottom: 0, trailing: Spacing.space5)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .task(id: files) { sizes = await FileSize.bytes(ofEach: files) }
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

#Preview {
    StagedFilesSheet(
        files: [
            URL(filePath: "/tmp/Holiday-photo-album.zip"),
            URL(filePath: "/tmp/notes.txt"),
            URL(filePath: "/tmp/IMG_0042.HEIC"),
        ], send: {}, discard: {})
}
