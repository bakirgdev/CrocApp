import SwiftUI

/// F36: explains the code-phrase / PAKE / untrusted-relay model.
/// Facts: docs/knowledge/what-is-croc.md.
struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                item("key.fill", "One code, one transfer",
                     "Every transfer uses a short one-time code phrase. Whoever has the code is the transfer partner — share it over a channel you trust, then it expires with the transfer.")
                item("lock.shield.fill", "Strong keys from short codes",
                     "Both devices run PAKE (password-authenticated key exchange) to turn the code phrase into a strong encryption key. The code itself never crosses the network, and a wrong code fails immediately.")
                item("lock.fill", "End-to-end encrypted",
                     "Everything is encrypted on your device and decrypted only on the other one. Nothing in between can read it.")
                item("antenna.radiowaves.left.and.right", "The relay is just a pipe",
                     "When devices can't connect directly, an internet relay forwards the encrypted stream. The relay never has the key: it sees only ciphertext. You can also run your own relay and set it in Settings.")
                item("wifi", "Local network when possible",
                     "Devices on the same network transfer directly — the data never leaves your network. The local path and the relay race; the faster one wins.")
                item("checkmark.shield.fill", "You stay in control",
                     "Nothing is saved without your OK: incoming transfers show a file preview you accept or decline. Auto-accept is off unless you turn it on.")
            }
            .padding()
            .frame(maxWidth: 480)
        }
        .navigationTitle("How it works")
    }

    private func item(_ icon: String, _ title: String, _ text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
        }
    }
}
