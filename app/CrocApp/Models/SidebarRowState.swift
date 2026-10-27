import CrocKit
import Foundation

/// What the sidebar row of the transfer's direction shows (design/components.md
/// → SidebarRow): while the transfer is starting, waiting, asking for an answer
/// or moving bytes. A finished or failed transfer leaves every row at rest,
/// because the result is in the detail and in a notification.
struct SidebarRowState: Equatable {
    /// The phase without its payload. A change here is announced once; a
    /// progress tick only changes `percent`.
    enum Kind: Equatable {
        case connecting, waiting, review, transferring
    }

    let kind: Kind
    /// The integer percent of the whole transfer; nil when its total size is
    /// unknown, where the row says the direction word instead.
    let percent: Int?

    init?(phase: TransferController.Phase, progress: TransferProgress?) {
        switch phase {
        case .starting, .connecting: kind = .connecting
        case .waiting: kind = .waiting
        case .confirmSend, .incoming: kind = .review
        case .transferring: kind = .transferring
        case .idle, .done, .stored, .failed: return nil
        }
        percent = kind == .transferring ? Self.percent(of: progress) : nil
    }

    static func percent(of progress: TransferProgress?) -> Int? {
        guard let progress, progress.totalSize > 0 else { return nil }
        let done = Double(progress.bytesFinished + progress.fileSent)
        return min(100, max(0, Int((done / Double(progress.totalSize) * 100).rounded())))
    }
}

extension TransferController.Phase {
    /// A question waits for the user's answer: the accept gate of a receive, or
    /// the confirm of a send that asked both sides to confirm.
    var needsAnswer: Bool {
        switch self {
        case .confirmSend, .incoming: true
        default: false
        }
    }

    /// Cancel is on screen, or would be: not at the accept gate, where it would
    /// answer the sender on the user's behalf (components.md → AcceptGate), and
    /// not once the transfer has ended.
    var canCancel: Bool {
        switch self {
        case .starting, .waiting, .connecting, .confirmSend, .transferring: true
        default: false
        }
    }

    /// The code phrase of a send that waits for the other device.
    var shownCode: String? {
        guard case .waiting(let code) = self else { return nil }
        return code
    }
}
