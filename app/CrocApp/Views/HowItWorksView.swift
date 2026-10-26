import SwiftUI

/// Explains the code-phrase / PAKE / untrusted-relay model.
/// Facts: docs/knowledge/what-is-croc.md.
struct HowItWorksView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                TrustBadge(relay: settings.relayKind, variant: .full)
                item(
                    "key.fill", "One code, one transfer",
                    "Every transfer uses a short one-time code phrase. Whoever has the code is the transfer partner. Share it over a channel you trust; it expires with the transfer."
                )
                item(
                    "lock.shield.fill", "Strong keys from short codes",
                    "Both devices run PAKE (password-authenticated key exchange) to turn the code phrase into a strong encryption key. The code itself never crosses the network, and a wrong code fails immediately."
                )
                item(
                    "lock.fill", "End-to-end encrypted",
                    "Everything is encrypted on your device and decrypted only on the other one. Nothing in between can read it."
                )
                item(
                    "antenna.radiowaves.left.and.right", "The relay is just a pipe",
                    "When devices can't connect directly, an internet relay forwards the encrypted stream. By default that is one of croc's public relays, 1.getcroc.com to 4.getcroc.com (or the relay you set in Settings). The relay never has the key: it sees only ciphertext. You can also run your own relay."
                )
                item(
                    "wifi", "Local network when possible",
                    "Devices on the same network transfer directly, and the data never leaves your network. The local path and the relay race; the faster one wins."
                )
                item(
                    "checkmark.shield.fill", "You stay in control",
                    "Nothing is saved without your OK: a transfer you receive shows a file preview you accept or decline. Auto-Accept Transfers is off unless you turn it on."
                )
            }
            .padding(Spacing.space5)
            .frame(maxWidth: LayoutCap.contentMaxWidth)
        }
        .navigationTitle("How It Works")
    }

    private func item(_ icon: String, _ title: String, _ text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .font(.title3)
                // minWidth, not a fixed width: a fixed frame clips the glyph
                // at accessibility text sizes.
                .frame(minWidth: IconSize.large)
        }
    }
}
