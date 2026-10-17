import SwiftUI
import UniformTypeIdentifiers

/// Send queue and accept-gate row. design/components.md → FileRow. `isFirst` /
/// `isLast` drive the first/last corner rounding and the inter-row separator
/// for a card of rows in a `List`. A row with no `onRemove` (the accept gate)
/// draws no remove control.
struct FileRow: View {
    let name: String
    /// Nil when the size is unknown or the row is a folder.
    let size: Int64?
    let symbolName: String
    var isFirst: Bool = false
    var isLast: Bool = false
    var onRemove: (() -> Void)?

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

    /// A remote entry, as listed by the accept gate: name and size only.
    init(name: String, size: Int64, isFirst: Bool = false, isLast: Bool = false) {
        self.name = name
        self.size = size
        self.symbolName = Self.symbolName(
            extension: URL(filePath: name).pathExtension, isFolder: false)
        self.isFirst = isFirst
        self.isLast = isLast
        self.onRemove = nil
    }

    // components.md → FileRow: type glyph and remove control are both 20, not
    // one of IconSize's three steps, so this stays a private constant scaled
    // with Dynamic Type.
    @ScaledMetric(relativeTo: .callout) private var glyphSize: CGFloat = 20
    /// Pinned tail length for the middle-truncation rule (components.md →
    /// FileRow: the last 8 characters stay visible).
    private static let pinnedTailLength = 8

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
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

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: glyphSize))
                        .foregroundStyle(Color.textSecondary)
                        #if os(iOS)
                    .frame(
                        minWidth: ControlHeight.hitTargetMin, minHeight: ControlHeight.hitTargetMin
                    )
                    .contentShape(Rectangle())
                        #endif
                }
                .buttonVariant(.plain)
                .accessibilityLabel("Remove \(name)")
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
        size?.formatted(.byteCount(style: .file))
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
