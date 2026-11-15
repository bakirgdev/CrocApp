import SwiftUI

/// Monospaced entry for the `word-word-word` code phrase, with the system
/// `PasteButton` trailing. The paste affordance lives here rather than beside
/// the field at call sites.
struct CodeField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isInvalid: Bool = false
    /// Says in words what is wrong, shown under the field and read by
    /// VoiceOver with it.
    var invalidMessage: String?
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
    /// field stays calm while it is typed.
    @State private var hasSettled = false

    /// What `invalidMessage` says for a code shorter than the engine accepts.
    static var tooShortMessage: String {
        inflected(
            AttributedString(
                localized:
                    "A code phrase needs at least ^[\(EngineConstraints.minCodeLength) character](inflect: true).",
                comment: "The placeholder is the minimum number of characters a code needs."))
    }

    private var showsInvalid: Bool { isInvalid && hasSettled }

    var body: some View {
        VStack(alignment: .leading) {
            field
            if showsInvalid, let invalidMessage {
                Label {
                    Text(invalidMessage).foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                }
                .font(.footnote)
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
        HStack {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                .contentShape(.rect)
                .onTapGesture { isFocused = true }
                .font(.subheadline.monospaced())
                .tracking(0.5)
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
                // Send has a second PasteButton, and the system names both "Paste".
                .accessibilityLabel("Paste code")
                .accessibilityInputLabels(["Paste code"])
            }
        }
        .controlSize(.large)
    }
}
