import SwiftUI

/// The end-to-end encryption statement with the relay in use, shown once, on
/// How It Works.
struct TrustBadge: View {
    let relay: AppSettings.RelayKind

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text("End-to-end encrypted")
                    .font(.subheadline.weight(.semibold))
                Text(relayLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
        }
        .padding()
        .background(.green.opacity(0.14), in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    // Claim only what is true (voice.md → Claims): never more than that.
    private var relayLine: LocalizedStringKey {
        switch relay {
        case .localOnly:
            return "Local network only: nothing leaves your network"
        case .directToSender:
            return "Straight to the sender, no relay in between"
        case .custom(let address):
            return "Via custom relay \(address), which sees only encrypted data"
        case .publicDefault:
            return "Via the public croc relay, which sees only encrypted data"
        }
    }
}
