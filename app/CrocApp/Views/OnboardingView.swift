import SwiftUI

/// First-run explainer (onboarding-lite): the code-phrase mental model in
/// three lines, then out of the way forever. Full detail lives in
/// HowItWorksView; this sheet must not become a tour.
struct OnboardingView: View {
    let done: () -> Void

    // components.md → OnboardingSheet: mark glyph 56, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56

    var body: some View {
        VStack(spacing: Spacing.space7) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: markSize))
                .foregroundStyle(Color.accentFill)
                .accessibilityHidden(true)
            Text("Welcome to CrocApp")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: Spacing.space5) {
                bullet(
                    "key.fill",
                    "One code phrase does everything",
                    "Sending shows a short code phrase. Enter it on the other device and the two connect."
                )
                bullet(
                    "lock.fill",
                    "End-to-end encrypted",
                    "Files are encrypted with the code phrase. The relay only ever sees ciphertext."
                )
                bullet(
                    "globe",
                    "Works anywhere",
                    "Same Wi-Fi or different continents, transfers find the fastest path automatically."
                )
            }
            .frame(maxWidth: LayoutCap.contentMaxWidth)
            #if os(iOS)
            // Primes the camera (QR scan) and local-network (faster nearby
            // transfers) system prompts iOS raises later, so neither is a
            // surprise. macOS has no camera feature and no local-network
            // prompt in this app's flow, so this line is iOS-only.
            Text(
                "CrocApp will ask to use your camera (to scan QR codes) and your local network (for faster nearby transfers)."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: LayoutCap.contentMaxWidth)
            #endif
            Button {
                done()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonVariant(.prominent)
            .controlSize(.large)
            .frame(maxWidth: LayoutCap.contentMaxWidth)
        }
        .padding(Spacing.space8)
        #if os(macOS)
        .frame(width: LayoutCap.contentMaxWidth)
        #endif
    }

    private func bullet(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.space4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentFill)
                // minWidth, not a fixed width: a fixed frame clips the glyph
                // at accessibility text sizes.
                .frame(minWidth: IconSize.large)
            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview { OnboardingView(done: {}) }
