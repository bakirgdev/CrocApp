import SwiftUI

/// What the share extension handed over, for a yes or no before it is sent.
/// The rows are display only: Discard is the way to drop files from it.
struct StagedFilesSheet: View {
    let files: [URL]
    let send: () -> Void
    let discard: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(files.enumerated()), id: \.element) { index, url in
                    FileRow(
                        name: url.lastPathComponent,
                        size: Self.size(of: url),
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

    private static func size(of url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
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
