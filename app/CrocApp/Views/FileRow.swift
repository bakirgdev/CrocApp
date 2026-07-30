import SwiftUI
import UniformTypeIdentifiers

/// Send queue / incoming preview row. design/components.md → FileRow, lines
/// 108-114. `isFirst`/`isLast` drive the same first/last corner-rounding and
/// inter-row separator rules as SettingsRow, for a card of rows in a `List`.
struct FileRow: View {
    let url: URL
    var isFirst: Bool = false
    var isLast: Bool = false
    let onRemove: () -> Void

    // components.md lines 112/114, iconography.md "Sizes in use": type icon
    // and remove control are both 20 — not one of IconSize's three steps, so
    // this stays a private constant per DesignTokens.swift's own rule.
    private static let glyphSize: CGFloat = 20
    /// Pinned tail length for the middle-truncation rule (components.md
    /// line 114: "the last 8 characters ... are pinned").
    private static let pinnedTailLength = 8

    var body: some View {
        HStack(spacing: Spacing.space3) {
            Image(systemName: typeSymbolName)
                .font(.system(size: Self.glyphSize))
                .foregroundStyle(Color.accentFill)
                .accessibilityHidden(true)

            filenameLabel
                .font(.callout)  // typography.md: --type-callout is used for "file names"
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: Spacing.space3)

            if let sizeText {
                Text(sizeText)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: Self.glyphSize))
                    .foregroundStyle(Color.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(url.lastPathComponent)")
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

    private var rowShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? Radius.md : 0,
            bottomLeadingRadius: isLast ? Radius.md : 0,
            bottomTrailingRadius: isLast ? Radius.md : 0,
            topTrailingRadius: isFirst ? Radius.md : 0,
            style: .continuous
        )
    }

    // iconography.md → Mapping: folder/image/text/generic-doc rows.
    private var typeSymbolName: String {
        if url.hasDirectoryPath { return "folder" }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    private var sizeText: String? {
        guard !url.hasDirectoryPath,
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return nil }
        return Int64(size).formatted(.byteCount(style: .file))
    }

    // components.md line 114: last `pinnedTailLength` characters (extension
    // + tail) stay in a non-shrinking span so the extension is always
    // legible; only the head ellipsises. No native SwiftUI truncation mode
    // does this, so it's built from two `Text` views instead of relying on
    // `.truncationMode(.middle)`.
    @ViewBuilder
    private var filenameLabel: some View {
        let name = url.lastPathComponent
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
