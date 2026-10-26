import SwiftUI

/// End-to-end encryption badge + active relay indicator, shown on the
/// waiting and transferring screens. Relay kind is captured at transfer
/// start (TransferController.activeRelay) so it can't drift mid-transfer.
/// design/components.md → TrustBadge.
struct TrustBadge: View {
    enum Variant {
        /// Inline capsule. Sits in the Home header and on transfer screens.
        case pill
        /// Row card for the How It Works screen.
        case full
    }

    let relay: AppSettings.RelayKind
    /// Defaulted so existing `TrustBadge(relay:)` call sites keep compiling.
    var variant: Variant = .pill

    // components.md → TrustBadge: pill lock at 14, full glyph at 19, scaled
    // with Dynamic Type.
    @ScaledMetric(relativeTo: .footnote) private var pillGlyph: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var fullGlyph: CGFloat = 19
    @ScaledMetric(relativeTo: .subheadline) private var fullCircle: CGFloat =
        ComponentMetrics.trustBadgeFullCircle

    var body: some View {
        switch variant {
        case .pill: pill
        case .full: full
        }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: Spacing.space2) {
            Image(systemName: "lock.fill")
                .font(.system(size: pillGlyph, weight: .semibold))
                .foregroundStyle(Color.statusSuccess)
                .accessibilityHidden(true)
            // The pill's label is primary, not success: success on its own
            // tint is 1.98:1 in light (components.md → TrustBadge). Only the
            // glyph carries the success color.
            Text("End-to-end encrypted")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, Spacing.space2)
        .padding(.leading, Spacing.space3)
        .padding(.trailing, Spacing.space4)
        .background(Color.statusSuccessTint, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Full

    private var full: some View {
        HStack(spacing: Spacing.space4) {
            ZStack {
                Circle()
                    .fill(Color.statusSuccess)
                    .frame(width: fullCircle, height: fullCircle)
                // The full variant escapes the pill's contrast problem by
                // inverting: a solid success fill with the glyph knocked out
                // of it in --paper (components.md → TrustBadge).
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: fullGlyph, weight: .semibold))
                    .foregroundStyle(Color.paper)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.space1) {
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
                .strokeBorder(
                    Color.statusSuccess.opacity(ComponentMetrics.statusBorderOpacity),
                    lineWidth: BorderWidth.hairline)
        )
        .accessibilityElement(children: .combine)
    }

    // Claim only what is true (content.md → Claims): never more than that.
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
