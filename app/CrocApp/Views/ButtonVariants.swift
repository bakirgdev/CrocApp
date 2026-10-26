import SwiftUI

/// The five button variants. design/components.md → Button; the SwiftUI
/// translation is design/swiftui.md → Components. Views never style a button
/// ad hoc: they pick a variant.
enum ButtonVariant {
    case prominent
    case secondary
    case destructive
    case destructiveTinted
    case plain
}

/// A `PrimitiveButtonStyle` rather than a bare modifier chain: the label color
/// has to sit on the label content itself, inside the system style, or the
/// style repaints it with the global tint (`Color.accentFill`, 3.41:1 as text).
private struct ButtonVariantStyle: PrimitiveButtonStyle {
    let variant: ButtonVariant
    @Environment(\.isEnabled) private var isEnabled
    #if os(macOS)
    @Environment(\.appearsActive) private var appearsActive
    #endif

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            labelContent(configuration.label)
        }
        .buttonBorderShape(.capsule)

        switch variant {
        case .prominent:
            button.buttonStyle(.borderedProminent).tint(Color.accentSolid)
        case .secondary:
            button.buttonStyle(.bordered).tint(Color.accentFill)
        case .destructive:
            button.buttonStyle(.borderedProminent).tint(Color.statusError)
        case .destructiveTinted:
            button.buttonStyle(.bordered).tint(Color.statusError)
        case .plain:
            button.buttonStyle(.borderless).tint(Color.accentFill)
        }
    }

    /// The pinned colors assume the enabled, active fill. A disabled button or
    /// an inactive macOS window gets a system fill, so the system picks the label.
    private var usesVariantLabelColor: Bool {
        #if os(macOS)
        isEnabled && appearsActive
        #else
        isEnabled
        #endif
    }

    /// Every variant is semibold (design/components.md → Button); the system
    /// bordered styles default to regular.
    @ViewBuilder
    private func labelContent(_ label: Configuration.Label) -> some View {
        if usesVariantLabelColor {
            label.fontWeight(.semibold).foregroundStyle(labelColor)
        } else {
            label.fontWeight(.semibold)
        }
    }

    private var labelColor: Color {
        switch variant {
        case .prominent: Color.onAccent
        case .secondary: Color.accentTextOnTint
        case .destructive: Color.onStatus
        case .destructiveTinted: Color.textPrimary
        case .plain: Color.accentTextOnTint
        }
    }
}

extension View {
    /// Applies a button variant. Large primary actions add `.controlSize(.large)`.
    func buttonVariant(_ variant: ButtonVariant) -> some View {
        buttonStyle(ButtonVariantStyle(variant: variant))
    }
}

#Preview("Button variants") {
    VStack(spacing: Spacing.space4) {
        Button("Accept") {}.buttonVariant(.prominent).controlSize(.large)
        Button("Copy Code") {}.buttonVariant(.secondary)
        Button("Decline") {}.buttonVariant(.destructive)
        // Verbatim, so these preview-only labels stay out of the String Catalog.
        Button {
        } label: {
            Text(verbatim: "Clear History")
        }
        .buttonVariant(.destructiveTinted)
        Button("Review") {}.buttonVariant(.plain)
        Button {
        } label: {
            Text(verbatim: "Disabled")
        }
        .buttonVariant(.prominent).disabled(true)
    }
    .padding(Spacing.space5)
}
