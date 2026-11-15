import SwiftUI

/// First-run explainer (onboarding-lite): the code-phrase mental model in
/// three lines, then out of the way forever. Full detail lives in
/// HowItWorksView; this sheet must not become a tour.
struct OnboardingView: View {
    let done: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title) private var bulletGlyphSize: CGFloat = 28
    private static let glyphColumnRatio: CGFloat = 1.25

    var body: some View {
        // Scrolls when the text is large enough that the column is taller than
        // the sheet. Content that fits is centered, as before.
        ScrollView {
            column
                .padding(32)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center, for: .alignment)
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    private var column: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: markSize))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Welcome to CrocApp")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 16) {
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
            .frame(maxWidth: 480)
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
            .frame(maxWidth: 480)
            #endif
            Button {
                done()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: 480)
        }
    }

    private func bullet(
        _ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey
    ) -> some View {
        // The glyph sits above the text at accessibility sizes: a glyph column
        // would leave the text a few characters per line.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            Image(systemName: icon)
                .font(.system(size: bulletGlyphSize))
                .foregroundStyle(Color.accentColor)
                // minWidth, not a fixed width: a fixed frame clips the glyph
                // at accessibility text sizes. The width has headroom over the
                // glyph so every bullet's text starts at the same x: the globe
                // is about 1.1 times its size. Stacked, there is no column.
                .frame(minWidth: stacked ? nil : bulletGlyphSize * Self.glyphColumnRatio)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview { OnboardingView(done: {}) }
