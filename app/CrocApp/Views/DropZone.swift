import SwiftUI

/// The empty send target. design/components.md → DropZone. Drawn, because no
/// system control does the job; it is never the only way in, so every use sits
/// beside a real file-picker button. The drop destination itself stays with the
/// caller, which passes the `isTargeted` state in.
struct DropZone: View {
    enum Size {
        case regular
        case compact
    }

    let title: LocalizedStringKey
    var hint: LocalizedStringKey?
    var size: Size = .regular
    let isTargeted: Bool

    // components.md → DropZone: min height 168 (menu bar 96), 2pt stroke dashed
    // 6 on 4 off, glyph 44 (34 compact, implementation.md → Icons), scaled
    // with Dynamic Type. SendView reuses the height and the stroke for the staged
    // list and its drag-over border.
    static let minHeight: CGFloat = 168
    static let strokeWidth: CGFloat = 2
    private static let compactMinHeight: CGFloat = 96
    private static let dashLength: CGFloat = 6
    private static let dashGap: CGFloat = 4
    @ScaledMetric(relativeTo: .largeTitle) private var regularGlyph: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var compactGlyph: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
    }

    var body: some View {
        VStack(spacing: Spacing.space4) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: size == .regular ? regularGlyph : compactGlyph))
                .foregroundStyle(isTargeted ? Color.accentTextOnTint : Color.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(isTargeted ? Color.accentTextOnTint : Color.textPrimary)
            if let hint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.space5)
        .frame(
            maxWidth: .infinity,
            minHeight: size == .regular ? Self.minHeight : Self.compactMinHeight
        )
        // --color-fill-tertiary is the system fill ladder (implementation.md → Not mirrored).
        .background(
            isTargeted ? AnyShapeStyle(Color.accentTint) : AnyShapeStyle(.fill.tertiary),
            in: shape
        )
        .overlay {
            if isTargeted {
                shape.strokeBorder(Color.accentFill, lineWidth: Self.strokeWidth)
            } else {
                shape.strokeBorder(
                    Color.separatorToken,
                    style: StrokeStyle(
                        lineWidth: Self.strokeWidth, dash: [Self.dashLength, Self.dashGap]))
            }
        }
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationFast), value: isTargeted
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Idle") {
    DropZone(
        title: "Drop files or folders here", hint: "or add them with the buttons below",
        isTargeted: false
    )
    .padding(Spacing.space5)
}

#Preview("Drag over") {
    DropZone(
        title: "Drop files or folders here", hint: "or add them with the buttons below",
        isTargeted: true
    )
    .padding(Spacing.space5)
}
