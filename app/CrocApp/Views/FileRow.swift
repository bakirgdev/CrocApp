import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

/// Send queue, accept-gate and received-file row. design/components.md →
/// FileRow. `isFirst` / `isLast` drive the first/last corner rounding and the
/// inter-row separator for a card of rows in a `List`. A row with no
/// `onRemove` (the accept gate) draws no remove control.
struct FileRow: View {
    let name: String
    /// Nil when the size is unknown or the row is a folder.
    let size: Int64?
    let symbolName: String
    var isFirst: Bool = false
    var isLast: Bool = false
    var onRemove: (() -> Void)?
    private var received: Received?

    /// What a received row does (components.md → FileRow, Received).
    struct Received {
        let url: URL
        /// Opens Quick Look. nil for a folder, which has none.
        let quickLook: (() -> Void)?
        /// Show in Finder or Show in Files. nil where neither can show it.
        let reveal: (() -> Void)?
    }

    /// A staged local file: name, size and glyph come from the URL.
    init(url: URL, isFirst: Bool = false, isLast: Bool = false, onRemove: @escaping () -> Void) {
        let isFolder = url.hasDirectoryPath
        self.name = url.lastPathComponent
        self.size =
            isFolder
            ? nil
            : (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        self.symbolName = Self.symbolName(extension: url.pathExtension, isFolder: isFolder)
        self.isFirst = isFirst
        self.isLast = isLast
        self.onRemove = onRemove
    }

    /// A remote entry, as listed by the accept gate: name and size only. The
    /// name is the sender's, so it is drawn in its shown form: a name
    /// `ReceivedName` blocks never renders raw.
    init(name: String, size: Int64, isFirst: Bool = false, isLast: Bool = false) {
        self.name = ReceivedName.shown(name)
        self.size = size
        self.symbolName = Self.symbolName(
            extension: URL(filePath: name).pathExtension, isFolder: false)
        self.isFirst = isFirst
        self.isLast = isLast
        self.onRemove = nil
    }

    /// An item a completed receive wrote. Its name passed `ReceivedName`
    /// before anything was saved, and is still drawn in its shown form.
    init(
        received item: ReceivedItem, isFirst: Bool = false, isLast: Bool = false,
        quickLook: @escaping () -> Void, reveal: (() -> Void)?
    ) {
        self.name = ReceivedName.shown(item.url.lastPathComponent)
        self.size = item.size
        self.symbolName = Self.symbolName(
            extension: item.url.pathExtension, isFolder: item.isFolder)
        self.isFirst = isFirst
        self.isLast = isLast
        self.onRemove = nil
        self.received = Received(
            url: item.url, quickLook: item.isFolder ? nil : quickLook, reveal: reveal)
    }

    // components.md → FileRow: type glyph, remove control and share glyph are
    // all 20, not one of IconSize's three steps, so this stays a private
    // constant scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .callout) private var glyphSize: CGFloat = 20
    /// Pinned tail length for the middle-truncation rule (components.md →
    /// FileRow: the last 8 characters stay visible).
    private static let pinnedTailLength = 8

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.space3) {
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
                            .font(.system(size: glyphSize))
                            .foregroundStyle(Color.textSecondary)
                            .hitTarget()
                    }
                    .buttonVariant(.plain)
                    .accessibilityLabel("Remove \(name)")
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
        .padding(.vertical, Spacing.space3)
        .frame(minHeight: ComponentMetrics.fileRowMinHeight)
        .background(Color.surfaceCard, in: rowShape)
        .overlay(alignment: .bottom) {
            // spacing-layout.md → Borders: every row but the last draws the
            // inset hairline separator; the last omits it so corners stay clean.
            if !isLast {
                Rectangle()
                    .fill(Color.separatorToken)
                    .frame(height: BorderWidth.hairlineHalf)
            }
        }
        .clipShape(rowShape)
        .modifier(ReceivedRowActions(received: received))
    }

    /// Glyph, name and size.
    private var info: some View {
        HStack(spacing: Spacing.space3) {
            Image(systemName: symbolName)
                .font(.system(size: glyphSize))
                .foregroundStyle(Color.accentFill)
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                // The pinned-tail label keeps 8 characters unshrinkable, which
                // is wider than the row at these sizes: wrap the name and put
                // the size under it.
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text(name)
                        .font(.callout)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                    sizeLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                filenameLabel
                    .font(.callout)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: Spacing.space3)

                sizeLabel
            }
        }
    }

    private func shareLink(_ url: URL) -> some View {
        ShareLink(item: url) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: glyphSize))
                .foregroundStyle(Color.textSecondary)
                .hitTarget()
        }
        .buttonVariant(.plain)
        .accessibilityLabel(Text("Share \(name)"))
    }

    @ViewBuilder private var sizeLabel: some View {
        if let sizeText {
            Text(sizeText)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var rowShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? Radius.md : 0,
            bottomLeadingRadius: isLast ? Radius.md : 0,
            bottomTrailingRadius: isLast ? Radius.md : 0,
            topTrailingRadius: isFirst ? Radius.md : 0,
            style: .continuous
        )
    }

    // design/iconography.md → Shared meanings: folder, image, text, generic file.
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

    // components.md → FileRow: last `pinnedTailLength` characters (extension
    // + tail) stay in a non-shrinking span so the extension is always
    // legible; only the head ellipsises. No native SwiftUI truncation mode
    // does this, so it's built from two `Text` views instead of relying on
    // `.truncationMode(.middle)`.
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

/// A received row's context menu and drag-out (design/platforms.md →
/// Received files). The menu repeats the row's own actions; it adds none.
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
