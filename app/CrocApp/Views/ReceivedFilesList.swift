import QuickLook
import SwiftUI

/// What a completed receive wrote, as `FileRow`s (docs/knowledge/app-ui-architecture.md →
/// System surfaces). Quick Look previews a file; the app never opens one itself.
struct ReceivedFilesList: View {
    let folder: URL
    let names: [String]
    let since: Date
    /// A folder the user picked: reading it, and previewing from it, needs
    /// its security scope, which the controller let go at the end.
    let isScoped: Bool
    let reveal: ((URL) -> Void)?

    @State private var items: [ReceivedItem] = []
    @State private var preview: URL?
    /// The folder whose security scope this list holds, so a new `folder` swaps scopes.
    @State private var heldScope: URL?
    @ScaledMetric private var listMaxHeight = TransferStatusView.fileListMaxHeight

    var body: some View {
        ZStack {
            if !items.isEmpty {
                ScrollView {
                    GroupBox {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                FileRow(
                                    received: item,
                                    quickLook: { preview = item.url },
                                    reveal: reveal.map { reveal in { reveal(item.url) } })
                                if index < items.count - 1 { Divider() }
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: listMaxHeight)
            }
        }
        .quickLookPreview($preview, in: items.filter { !$0.isFolder }.map(\.url))
        .task(id: folder) {
            if heldScope != folder {
                heldScope?.stopAccessingSecurityScopedResource()
                heldScope = isScoped && folder.startAccessingSecurityScopedResource() ? folder : nil
            }
            let names = names
            let folder = folder
            let since = since
            items = await Task.detached(priority: .userInitiated) {
                ReceivedItems.locate(names: names, in: folder, since: since)
            }.value
        }
        .onDisappear {
            heldScope?.stopAccessingSecurityScopedResource()
            heldScope = nil
        }
    }
}
