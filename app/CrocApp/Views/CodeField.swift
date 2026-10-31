import SwiftUI

/// Monospaced entry for the `word-word-word` code phrase.
/// design/components.md → CodeField.
///
/// The paste affordance is part of this component's own spec (the wrapper's
/// asymmetric padding — 14 leading for text, 6 trailing — exists to seat a
/// system-sized `PasteButton` flush inside the 50pt pill), so it lives here rather
/// than beside the field at call sites. The system owns `PasteButton`'s
/// chrome for paste-permission-UI reasons and only exposes
/// `.buttonBorderShape` / `.tint` / `.labelStyle` — the exact spec colors
/// (`--color-accent-text-on-tint` on `--color-accent-tint`) are not
/// reachable through that surface, so this gets as close as the API allows.
struct CodeField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isInvalid: Bool = false
    /// Says in words what is wrong, shown under the field and read by
    /// VoiceOver with it; the red border alone is not enough.
    var invalidMessage: String?
    var isDisabled: Bool = false
    /// Receives the pasted string on the main actor; the call site decides
    /// what counts as a valid paste (e.g. ReceiveView's deeplink parsing).
    /// Nil hides the paste button entirely.
    var onPaste: ((String) -> Void)?
    /// Return was pressed. The field has already marked a wrong value as wrong.
    var onSubmit: (() -> Void)?
    var submitLabel: SubmitLabel = .done
    /// Puts the caret here when the field appears (`HardwareKeyboard.isExpected`).
    var focusesOnAppear = false

    @FocusState private var isFocused: Bool
    /// The user has said they are done with a value that is wrong: Return, or
    /// leaving the field. Until then a short code is just unfinished, so the
    /// field stays calm while it is typed (components.md → CodeField).
    @State private var hasSettled = false

    /// What `invalidMessage` says for a code shorter than the engine accepts.
    static var tooShortMessage: String {
        inflected(
            AttributedString(
                localized:
                    "A code phrase needs at least ^[\(EngineConstraints.minCodeLength) character](inflect: true).",
                comment: "The placeholder is the minimum number of characters a code needs."))
    }

    // components.md → CodeField: wrapper padding is `0 6px 0 14px`, not a
    // Spacing step, so it is a private constant of this component.
    private static let leadingPadding: CGFloat = 14
    private static let trailingPadding: CGFloat = 6

    private var showsInvalid: Bool { isInvalid && hasSettled }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            field
            if showsInvalid, let invalidMessage {
                Text(invalidMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        // A fixed value is right again at once, so the next mistake starts calm.
        .onChange(of: isInvalid) { _, invalid in
            if !invalid { hasSettled = false }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, isInvalid { hasSettled = true }
        }
        .task {
            guard focusesOnAppear else { return }
            isFocused = true
        }
    }

    private var field: some View {
        HStack(spacing: Spacing.space2) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline.monospaced())
                .tracking(Tracking.code)
                .focused($isFocused)
                .submitLabel(submitLabel)
                .onSubmit {
                    if isInvalid { hasSettled = true }
                    onSubmit?()
                }
                .accessibilityHint(showsInvalid ? (invalidMessage ?? "") : "")
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
        .frame(minHeight: ControlHeight.large)
        .background(
            Color.surfaceBase, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(borderColor, lineWidth: BorderWidth.hairline)
        )
        .disabled(isDisabled)
        .opacity(isDisabled ? Opacity.disabledContainer : 1)
    }

    // components.md → CodeField: separator idle, accent focused, error invalid.
    private var borderColor: Color {
        if showsInvalid { return .statusError }
        if isFocused { return .accentFill }
        return .separatorToken
    }
}
