import SwiftUI

/// End-to-end encryption badge + active relay indicator, shown on the
/// waiting and transferring screens. Relay kind is captured at transfer
/// start (TransferController.activeRelay) so it can't drift mid-transfer.
struct TrustBadge: View {
    enum Variant {
        /// Inline capsule. Sits in the Home header and on transfer screens.
        case pill
        /// Row card for the How It Works screen.
        case full
    }

    let relay: AppSettings.RelayKind
    var variant: Variant = .pill

    var body: some View {
        switch variant {
        case .pill: pill
        case .full: full
        }
    }

    private var pill: some View {
        // The label is primary, not success: success on its own tint is 1.98:1
        // in light. Only the glyph carries the success color.
        Label {
            Text("End-to-end encrypted")
        } icon: {
            Image(systemName: "lock.fill").foregroundStyle(.green)
        }
        .font(.footnote.weight(.semibold))
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(.green.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private var full: some View {
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
