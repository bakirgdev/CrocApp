import SwiftUI

/// The empty send target. Drawn, because no system control does the job; it is never the only way in, so every use sits
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

    // SendView reuses the height and the stroke for the staged list and its
    // drag-over border.
    static let minHeight: CGFloat = 168
    static let strokeWidth: CGFloat = 2
    private static let compactMinHeight: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 20)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(size == .regular ? .largeTitle : .title)
                .imageScale(.large)
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            if let hint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(
            maxWidth: .infinity,
            minHeight: size == .regular ? Self.minHeight : Self.compactMinHeight
        )
        .background(
            isTargeted
                ? AnyShapeStyle(Color.accentColor.opacity(0.14))
                : AnyShapeStyle(.fill.tertiary),
            in: shape
        )
        .overlay {
            if isTargeted {
                shape.strokeBorder(Color.accentColor, lineWidth: Self.strokeWidth)
            } else {
                shape.strokeBorder(
                    .separator,
                    style: StrokeStyle(lineWidth: Self.strokeWidth, dash: [6, 4]))
            }
        }
        .animation(
            reduceMotion ? nil : .default, value: isTargeted
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Idle") {
    DropZone(
        title: "Drop files or folders here", hint: "or add them with the buttons below",
        isTargeted: false
    )
    .padding()
}

#Preview("Drag over") {
    DropZone(
        title: "Drop files or folders here", hint: "or add them with the buttons below",
        isTargeted: true
    )
    .padding()
}
