import SwiftUI

/// Monospaced entry for the `NNNN-word-word-word` transfer code.
/// design/components.md → CodeField, lines 82-91.
///
/// The paste affordance is part of this component's own spec (the wrapper's
/// asymmetric padding — 14 leading for text, 6 trailing — exists to seat a
/// 38pt `PasteButton` flush inside the 50pt pill), so it lives here rather
/// than beside the field at call sites. The system owns `PasteButton`'s
/// chrome for paste-permission-UI reasons and only exposes
/// `.buttonBorderShape` / `.tint` / `.labelStyle` — the exact spec colors
/// (`--color-accent-text-on-tint` on `--color-accent-tint`) are not
/// reachable through that surface, so this gets as close as the API allows.
struct CodeField: View {
    let placeholder: String
    @Binding var text: String
    var isInvalid: Bool = false
    var isDisabled: Bool = false
    /// Receives the pasted string on the main actor; the call site decides
    /// what counts as a valid paste (e.g. ReceiveView's deeplink parsing).
    /// Nil hides the paste button entirely.
    var onPaste: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    // components.md line 86: wrapper padding is `0 6px 0 14px`, not a
    // Spacing step — single-component constant per DesignTokens.swift's own
    // rule ("Anything used by only one component stays a private constant").
    private static let leadingPadding: CGFloat = 14
    private static let trailingPadding: CGFloat = 6
    private static let codeTracking: CGFloat = 0.5  // --tracking-code, typography.md

    var body: some View {
        HStack(spacing: Spacing.space2) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body.monospaced())  // --type-code-body, swiftui-mapping.md → Typography
                .tracking(Self.codeTracking)
                .focused($isFocused)
                .autocorrectionDisabled()
                #if os(iOS)
            .textInputAutocapitalization(.never)
                #endif

            if let onPaste {
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in onPaste(pasted) }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle(radius: Radius.sm))
                .tint(Color.accentFill)
            }
        }
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, Self.trailingPadding)
        .frame(height: ControlHeight.large)
        .background(
            Color.surfaceBase, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(borderColor, lineWidth: BorderWidth.hairline)
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    // components.md line 86: separator idle → accent focused → error invalid.
    private var borderColor: Color {
        if isInvalid { return .statusError }
        if isFocused { return .accentFill }
        return .separatorToken
    }
}
