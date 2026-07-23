import SwiftUI

/// F36: end-to-end encryption badge + active relay indicator, shown on the
/// waiting and transferring screens. Relay kind is captured at transfer
/// start (TransferController.activeRelay) so it can't drift mid-transfer.
struct TrustBadge: View {
    let relay: AppSettings.RelayKind

    var body: some View {
        VStack(spacing: 2) {
            Label("End-to-end encrypted", systemImage: "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
            Text(relayLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var relayLine: String {
        switch relay {
        case .localOnly:
            return "Local network only — nothing leaves your network"
        case .custom(let address):
            return "Via custom relay \(address) — it sees only encrypted data"
        case .publicDefault:
            return "Via the public croc relay — it sees only encrypted data"
        }
    }
}
