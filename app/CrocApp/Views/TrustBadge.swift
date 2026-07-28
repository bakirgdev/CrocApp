import SwiftUI

/// F36: end-to-end encryption badge + active relay indicator, shown on the
/// waiting and transferring screens. Relay kind is captured at transfer
/// start (TransferController.activeRelay) so it can't drift mid-transfer.
/// design/components.md → TrustBadge, lines 169-178.
struct TrustBadge: View {
    enum Variant {
        /// Inline capsule. Sits in the Home header and on transfer screens.
        case pill
        /// Row card for the "How it works" trust screen.
        case full
    }

    let relay: AppSettings.RelayKind
    /// Defaulted so existing `TrustBadge(relay:)` call sites keep compiling.
    var variant: Variant = .pill

    var body: some View {
        switch variant {
        case .pill: pill
        case .full: full
        }
    }

    // MARK: - Pill

    // components.md line 173: block/inline-start/inline-end padding 5/9/11,
    // icon 14 — components.md's own web-only token table, kept as component
    // constants here per its instruction not to scatter them at call sites.
    // iconography.md line 78: pill icon 14, stroke 2.2.
    private var pill: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.statusSuccess)
                .accessibilityHidden(true)
            // The pill's label is primary, not success: success on its own
            // tint is 1.98:1 in light (components.md line 176). Only the
            // glyph carries the success color.
            Text("End-to-end encrypted")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 5)
        .padding(.leading, 9)
        .padding(.trailing, 11)
        .background(Color.statusSuccessTint, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Full

    // components.md line 174: radius-md, success tint background, 22%
    // success border, 34px solid-success circle, --paper shield-check at 19.
    // iconography.md line 79: full-circle glyph 19, stroke 2.
    private var full: some View {
        HStack(spacing: Spacing.space4) {
            ZStack {
                Circle()
                    .fill(Color.statusSuccess)
                    .frame(
                        width: ComponentMetrics.trustBadgeFullCircle,
                        height: ComponentMetrics.trustBadgeFullCircle
                    )
                // The full variant escapes the pill's contrast problem by
                // inverting: a solid success fill with the glyph knocked out
                // of it in --paper (components.md line 176).
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.paper)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("End-to-end encrypted")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(relayLine)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.space5)
        .padding(.vertical, Spacing.space4)
        .background(
            Color.statusSuccessTint,
            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.statusSuccess.opacity(0.22), lineWidth: BorderWidth.hairline)
        )
        .accessibilityElement(children: .combine)
    }

    // Claim only what is true (components.md line 178): PAKE-authenticated,
    // end-to-end encrypted, relay sees ciphertext only — never more than that.
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
