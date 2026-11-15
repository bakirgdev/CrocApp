import Accessibility
import SwiftUI

/// The sender's code phrase: eyebrow, the code, and the Copy button.
/// The QR frame and caption stay with the caller. `compact` is the 300-wide
/// menu bar column.
struct CodePhraseDisplay: View {
    let code: String
    var compact = false

    var body: some View {
        VStack(spacing: compact ? nil : 16) {
            Text("Ready to send")
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            codeText
            CopyButton("Copy Code") { Clipboard.copySecret(code) }
        }
    }

    @ViewBuilder private var codeText: some View {
        let text = Text(code)
            .textSelection(.enabled)
            .tracking(0.5)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Code phrase")
            .accessibilityValue(code.replacingOccurrences(of: "-", with: ", "))
        if compact {
            text.font(.title3.monospaced().weight(.semibold))
        } else {
            text
                .font(.title.monospaced().bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                // A capsule clips the code once it wraps at large text sizes.
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }
}

/// A `secondary` Copy button that flips to `checkmark` and "Copied" for two
/// seconds after each copy, then flips back the same way. Copy Code, Copy Link and Copy Text
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
        .buttonStyle(.glass)
        .touchTargets()
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
                // A content transition only runs inside an animated transaction.
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .animation(
                    reduceMotion ? nil : .default, value: copied)
        }
    }
}

#Preview("Code phrase") {
    CodePhraseDisplay(code: "wiry-alpha-bravo").padding()
}
