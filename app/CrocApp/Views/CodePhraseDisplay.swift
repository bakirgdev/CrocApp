import Accessibility
import SwiftUI

/// The sender's code phrase: eyebrow, the code, and the Copy button.
/// design/components.md → CodePhraseDisplay and QRFrame (steps 1 to 3; the QR
/// frame and caption stay with the caller). `compact` is the 300-wide menu bar
/// column, which shows the code at `--type-title3`.
struct CodePhraseDisplay: View {
    let code: String
    var compact = false

    // components.md → CodePhraseDisplay: the code sits on a glass pill; its
    // padding is the pill's own, not a grid step.
    private static let pillPaddingInline = Spacing.space6

    var body: some View {
        VStack(spacing: compact ? Spacing.space3 : Spacing.space5) {
            Text("Ready to send")
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .tracking(Tracking.eyebrow)
                .foregroundStyle(Color.textSecondary)
            codeText
            CopyButton("Copy Code") { Clipboard.copySecret(code) }
        }
    }

    @ViewBuilder private var codeText: some View {
        let text = Text(code)
            .textSelection(.enabled)
            .tracking(Tracking.code)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Code phrase")
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

/// A `secondary` Copy button that flips to `checkmark` and "Copied" for two
/// seconds after each copy, then flips back the same way. design/components.md
/// → CodePhraseDisplay and QRFrame, step 3: Copy Code, Copy Link and Copy Text
/// all use it. The copy fires `.selection` and is announced (principles.md →
/// Haptics; principles.md → Accessibility).
struct CopyButton: View {
    let title: LocalizedStringKey
    let copy: () -> Void

    @State private var copies = 0
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let copiedDuration: Duration = .seconds(2)

    init(_ title: LocalizedStringKey, copy: @escaping () -> Void) {
        self.title = title
        self.copy = copy
    }

    var body: some View {
        Button {
            copy()
            copied = true
            copies += 1
            AccessibilityNotification.Announcement(String(localized: "Copied")).post()
        } label: {
            // Both labels are laid out and only one is shown, so the button
            // keeps its width and does not resize under the pointer.
            ZStack {
                label(title, systemImage: "doc.on.doc").hidden().accessibilityHidden(true)
                label(copied ? "Copied" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
            }
        }
        .buttonVariant(.secondary)
        // Restarts with every copy, so a second tap keeps "Copied" up for
        // another two seconds.
        .task(id: copies) {
            guard copies > 0 else { return }
            try? await Task.sleep(for: Self.copiedDuration)
            guard !Task.isCancelled else { return }
            copied = false
        }
        .phoneHaptic(trigger: copies) { _, _ in .selection }
    }

    private func label(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                // principles.md → Motion: the system draws the
                // effect; a content transition only runs inside an animated
                // transaction, which the token curve supplies.
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .animation(
                    reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: copied)
        }
    }
}

#Preview("Code phrase") {
    CodePhraseDisplay(code: "wiry-alpha-bravo").padding(Spacing.space5)
}
