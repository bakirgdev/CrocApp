import SwiftUI

/// First-run explainer (onboarding-lite): the code-phrase mental model in
/// three lines, then out of the way forever. Full detail lives in
/// HowItWorksView; this sheet must not become a tour.
struct OnboardingView: View {
    let done: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to CrocApp")
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 16) {
                bullet(
                    "key.fill",
                    "One code phrase does everything",
                    "Sending shows a short code. Enter it on the other device — that's the address and the password."
                )
                bullet(
                    "lock.fill",
                    "End-to-end encrypted",
                    "Files are encrypted with the code phrase. The relay only ever sees ciphertext."
                )
                bullet(
                    "globe",
                    "Works anywhere",
                    "Same Wi-Fi or different continents — transfers find the fastest path automatically."
                )
            }
            .frame(maxWidth: 420)
            Button {
                done()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 420)
        }
        .padding(32)
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    private func bullet(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview { OnboardingView(done: {}) }
