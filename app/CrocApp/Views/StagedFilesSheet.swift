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

    // A folder (from Finder's Share menu) has no size of its own: sum its files.
    private static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        func fileSize(_ url: URL) -> Int64 {
            (try? url.resourceValues(forKeys: keys).fileSize).map(Int64.init) ?? 0
        }
        guard url.hasDirectoryPath,
            let walk = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: Array(keys))
        else { return fileSize(url) }
        return walk.compactMap { $0 as? URL }.reduce(0) { $0 + fileSize($1) }
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
