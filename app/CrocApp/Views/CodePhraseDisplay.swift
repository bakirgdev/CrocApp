import SwiftUI

/// The sender's code phrase: eyebrow, the code, and the Copy button.
/// design/components.md → CodePhraseDisplay and QRFrame (steps 1 to 3; the QR
/// frame and caption stay with the caller). `compact` is the 300-wide menu bar
/// column, which shows the code at `--type-title3`.
struct CodePhraseDisplay: View {
    let code: String
    var compact = false

    @State private var copied = false

    // components.md → CodePhraseDisplay: the code sits on a glass pill; its
    // padding is the pill's own, not a grid step.
    private static let pillPaddingInline = Spacing.space6
    private static let copiedDuration: Duration = .seconds(2)

    var body: some View {
        VStack(spacing: compact ? Spacing.space3 : Spacing.space5) {
            Text("Ready to send")
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .tracking(Tracking.eyebrow)
                .foregroundStyle(Color.textSecondary)
            codeText
            Button {
                Clipboard.copySecret(code)
                copied = true
            } label: {
                Label(
                    copied ? "Copied" : "Copy Code",
                    systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonVariant(.secondary)
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: Self.copiedDuration)
                guard !Task.isCancelled else { return }
                copied = false
            }
            .phoneHaptic(trigger: copied) { _, new in new ? .selection : nil }
        }
    }

    @ViewBuilder private var codeText: some View {
        let text = Text(code)
            .textSelection(.enabled)
            .tracking(Tracking.code)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Transfer code")
            .accessibilityValue(code.replacingOccurrences(of: "-", with: ", "))
        if compact {
            text.font(.title3.monospaced().weight(.semibold))
        } else {
            text
                .codeHeroTextStyle()
                .padding(.horizontal, Self.pillPaddingInline)
                .padding(.vertical, Spacing.space4)
                // A capsule clips the code once it wraps at large text sizes.
                .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        }
    }
}
