import SwiftUI

/// A regular-width sidebar row whose trailing state is ours. The row is the system's: `Label`, selection and material. The
/// state is words first, and the row speaks it as one label.
struct SidebarRow: View {
    let item: AppRouter.SidebarItem
    let state: SidebarRowState?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            // The label speaks the state and the trailing view is hidden from
            // VoiceOver, so the row stays the system's one selectable element.
            Label(item.title, systemImage: item.symbol)
                .accessibilityLabel(spoken)
            Spacer(minLength: 8)
            if let state {
                trailing(state)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : .default, value: state)
    }

    private var spoken: String {
        state.map { Self.spoken(item, $0.kind, percent: $0.percent) } ?? item.title
    }

    @ViewBuilder private func trailing(_ state: SidebarRowState) -> some View {
        switch state.kind {
        case .connecting:
            word("Connecting")
        case .waiting:
            word("Waiting")
        case .review:
            // Our one filled mark on the sidebar: a question waits for a yes
            // or no, and the label is white on the accent.
            Text("Review")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor, in: Capsule())
        case .transferring:
            if let percent = state.percent {
                Text(Double(percent) / 100, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
            } else {
                word(item == .send ? "Sending" : "Receiving")
            }
        }
    }

    private func word(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// The row's spoken label, and what is announced when its phase changes
    /// ("Send, connecting"). A percent is read on the row but never announced
    /// (`percent` is nil there), so a progress tick says nothing.
    static func spoken(
        _ item: AppRouter.SidebarItem, _ kind: SidebarRowState.Kind, percent: Int?
    ) -> String {
        let words =
            switch kind {
            case .connecting:
                String(localized: "connecting", comment: "Said after a sidebar row's name.")
            case .waiting:
                String(
                    localized: "waiting for the other device",
                    comment: "Said after a sidebar row's name.")
            case .review:
                String(
                    localized: "needs your answer", comment: "Said after a sidebar row's name.")
            case .transferring:
                if let percent {
                    String(
                        localized: "\(percent) percent",
                        comment: "Said after a sidebar row's name. The placeholder is a number.")
                } else {
                    String(localized: "transferring", comment: "Said after a sidebar row's name.")
                }
            }
        return String(
            localized: "\(item.title), \(words)",
            comment: "A sidebar row's name, then its state. Both placeholders are words.")
    }
}

extension AppRouter.SidebarItem {
    var title: String {
        switch self {
        case .send: String(localized: "Send")
        case .receive: String(localized: "Receive")
        case .history: String(localized: "History")
        case .settings: String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .send: "arrow.up.circle"
        case .receive: "arrow.down.circle"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

#Preview("States") {
    List {
        SidebarRow(
            item: .send, state: SidebarRowState(phase: .waiting(code: "a-b-c"), percent: nil))
        SidebarRow(item: .receive, state: SidebarRowState(phase: .confirmSend, percent: nil))
        SidebarRow(item: .history, state: nil)
        SidebarRow(item: .settings, state: nil)
    }
    .listStyle(.sidebar)
}
