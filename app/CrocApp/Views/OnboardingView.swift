import SwiftUI

/// First-run explainer (onboarding-lite): the code-phrase mental model in
/// three lines, then out of the way forever. Full detail lives in
/// HowItWorksView; this sheet must not become a tour.
struct OnboardingView: View {
    let done: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // components.md → OnboardingSheet: mark glyph 56, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 56
    // components.md → OnboardingSheet: bullet glyphs at --icon-size-lg.
    @ScaledMetric(relativeTo: .title3) private var bulletGlyphSize: CGFloat = IconSize.large
    /// The glyph column's minimum width, as a multiple of the glyph size.
    private static let glyphColumnRatio: CGFloat = 1.25

    var body: some View {
        // Scrolls when the text is large enough that the column is taller than
        // the sheet. Content that fits is centered, as before.
        ScrollView {
            column
                .padding(Spacing.space8)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center, for: .alignment)
        #if os(macOS)
        .frame(width: LayoutCap.contentMaxWidth)
        #endif
    }

    private var column: some View {
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
            .foregroundStyle(Color.textSecondary)
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
    }

    private func bullet(
        _ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey
    ) -> some View {
        // The glyph sits above the text at accessibility sizes: a glyph column
        // would leave the text a few characters per line.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.space3))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.space4))
        return layout {
            Image(systemName: icon)
                .font(.system(size: bulletGlyphSize))
                .foregroundStyle(Color.accentFill)
                // minWidth, not a fixed width: a fixed frame clips the glyph
                // at accessibility text sizes. The width has headroom over the
                // glyph so every bullet's text starts at the same x: the globe
                // is about 1.1 times its size. Stacked, there is no column.
                .frame(minWidth: stacked ? nil : bulletGlyphSize * Self.glyphColumnRatio)
            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview { OnboardingView(done: {}) }
