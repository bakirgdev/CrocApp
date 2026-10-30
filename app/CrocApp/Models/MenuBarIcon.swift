#if os(macOS)
import CrocKit
import Foundation

/// The menu-bar glyph for a transfer phase (`knowledge/app-ui-architecture.md`,
/// "System surfaces"). One monochrome template glyph, no animation.
struct MenuBarIcon: Equatable {
    let symbol: String
    /// The state in words for VoiceOver; never a code phrase.
    let label: String
    /// The integer percent shown beside the glyph while bytes move.
    let percent: Int?

    init(phase: TransferController.Phase, progress: TransferProgress?) {
        let app = String(localized: "CrocApp")
        func describe(_ state: String) -> String {
            String(localized: "\(app): \(state)", comment: "Menu bar icon accessibility label.")
        }
        percent = phase == .transferring ? SidebarRowState.percent(of: progress) : nil
        switch phase {
        case .idle:
            symbol = "arrow.up.arrow.down.circle"
            label = app
        case .starting, .connecting:
            symbol = "arrow.up.arrow.down.circle.fill"
            label = describe(String(localized: "connecting"))
        case .waiting:
            symbol = "ellipsis.circle.fill"
            label = describe(String(localized: "waiting for the other device"))
        case .transferring:
            symbol = "arrow.up.arrow.down.circle.fill"
            label =
                percent.map { describe(String(localized: "transferring, \($0) percent")) }
                ?? describe(String(localized: "transferring"))
        case .confirmSend, .incoming:
            symbol = "exclamationmark.circle.fill"
            label = describe(String(localized: "waiting for your answer"))
        case .done(let summary, _):
            symbol = summary.success ? "checkmark.circle" : "exclamationmark.circle.fill"
            label = describe(
                summary.success
                    ? String(localized: "transfer complete")
                    : String(localized: "transfer finished with errors"))
        case .stored:
            symbol = "checkmark.circle"
            label = describe(String(localized: "link ready"))
        case .failed:
            symbol = "exclamationmark.circle.fill"
            label = describe(String(localized: "transfer failed"))
        }
    }
}
#endif
