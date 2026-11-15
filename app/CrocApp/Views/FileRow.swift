import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

/// Send queue, accept-gate and received-file row, for a `List` or a
/// `GroupBox` that supplies the card and the separators. A row with no
/// `onRemove` (the accept gate) draws no remove control.
struct FileRow: View {
    let name: String
    /// Nil when the size is unknown or the row is a folder.
    let size: Int64?
    let symbolName: String
    var onRemove: (() -> Void)?
    private var received: Received?

    /// What a received row does.
    struct Received {
        let url: URL
        /// Opens Quick Look. nil for a folder, which has none.
        let quickLook: (() -> Void)?
        /// Show in Finder or Show in Files. nil where neither can show it.
        let reveal: (() -> Void)?
    }

    /// A staged local file: name and glyph come from the URL. The size is the
    /// caller's, read off the main actor (`FileSize`); nil draws none.
    init(
        url: URL, size: Int64?, onRemove: @escaping () -> Void
    ) {
        self.name = url.lastPathComponent
        self.size = size
        let isFolder = url.hasDirectoryPath
        self.symbolName = Self.symbolName(extension: url.pathExtension, isFolder: isFolder)
        self.onRemove = onRemove
    }

    /// A remote entry, as listed by the accept gate: name and size only. The
    /// name is the sender's, so it is drawn in its shown form: a name
    /// `ReceivedName` blocks never renders raw.
    init(name: String, size: Int64?) {
        self.name = ReceivedName.shown(name)
        self.size = size
        self.symbolName = Self.symbolName(
            extension: URL(filePath: name).pathExtension, isFolder: false)
        self.onRemove = nil
    }

    /// An item a completed receive wrote. Its name passed `ReceivedName`
    /// before anything was saved, and is still drawn in its shown form.
    init(
        received item: ReceivedItem, quickLook: @escaping () -> Void, reveal: (() -> Void)?
    ) {
        self.name = ReceivedName.shown(item.url.lastPathComponent)
        self.size = item.size
        self.symbolName = Self.symbolName(
            extension: item.url.pathExtension, isFolder: item.isFolder)
        self.onRemove = nil
        self.received = Received(
            url: item.url, quickLook: item.isFolder ? nil : quickLook, reveal: reveal)
    }

    /// Pinned tail length for the middle-truncation rule: the last 8 characters
    /// stay visible.
    private static let pinnedTailLength = 8

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // The glyphs differ in width (photo is wider than doc): one scaled width
    // keeps the names in a column.
    @ScaledMetric(relativeTo: .title3) private var glyphWidth = 28

    var body: some View {
        HStack {
            if let received, let quickLook = received.quickLook {
                // The whole row but the share control is the Quick Look
                // button. System plain style: a row keeps its own colors,
                // where a button variant would tint the name.
                Button(action: quickLook) {
                    info.contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Quick Look \(name)"))
                .accessibilityValue(sizeText ?? "")
                shareLink(received.url)
            } else {
                info
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(name)")
                }
            }
        }
        .frame(minHeight: 44)
        .modifier(ReceivedRowActions(received: received))
    }

    private var info: some View {
        HStack {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: glyphWidth)
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                // The pinned-tail label keeps 8 characters unshrinkable, which
                // is wider than the row at these sizes: wrap the name and put
                // the size under it.
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    sizeLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                filenameLabel
                    .font(.callout)
                    .foregroundStyle(.primary)

                Spacer()

                sizeLabel
            }
        }
    }

    private func shareLink(_ url: URL) -> some View {
        ShareLink(item: url) {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Share \(name)"))
    }

    @ViewBuilder private var sizeLabel: some View {
        if let sizeText {
            Text(sizeText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private static func symbolName(extension ext: String, isFolder: Bool) -> String {
        if isFolder { return "folder" }
        guard let type = UTType(filenameExtension: ext) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    private var sizeText: String? {
        size.map(Self.sizeText)
    }

    /// "0 bytes" for an empty file: the formatter's default spells it "Zero KB".
    static func sizeText(_ size: Int64) -> String {
        size.formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    // The last `pinnedTailLength` characters (extension + tail) stay in a
    // non-shrinking span so the extension is always legible; only the head
    // ellipsises. No native SwiftUI truncation mode does this, so it's built
    // from two `Text` views instead of relying on `.truncationMode(.middle)`.
    @ViewBuilder
    private var filenameLabel: some View {
        if name.count <= Self.pinnedTailLength {
            Text(name).lineLimit(1)
        } else {
            let splitIndex = name.index(name.endIndex, offsetBy: -Self.pinnedTailLength)
            HStack(spacing: 0) {
                Text(name[..<splitIndex])
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(name[splitIndex...])
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
    }
}

/// A received row's context menu and drag-out (docs/knowledge/app-ui-architecture.md →
/// System surfaces). The menu repeats the row's own actions; it adds none.
private struct ReceivedRowActions: ViewModifier {
    let received: FileRow.Received?

    func body(content: Content) -> some View {
        if let received {
            content
                .contextMenu {
                    if let quickLook = received.quickLook {
                        Button("Quick Look", systemImage: "eye", action: quickLook)
                        ShareLink(item: received.url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let reveal = received.reveal {
                        #if os(macOS)
                        Button("Show in Finder", systemImage: "folder", action: reveal)
                        #else
                        Button("Show in Files", systemImage: "folder", action: reveal)
                        #endif
                    }
                }
                .dragOut(received.quickLook == nil ? nil : received.url)
        } else {
            content
        }
    }
}

extension View {
    /// Drags `url` out as the file itself, a copy: the received file stays.
    /// iPad and Mac only, because iPhone has no drag between apps.
    @ViewBuilder
    fileprivate func dragOut(_ url: URL?) -> some View {
        #if os(iOS)
        let dragsBetweenApps = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let dragsBetweenApps = true
        #endif
        if let url, dragsBetweenApps {
            onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL) }
        } else {
            self
        }
    }
}
