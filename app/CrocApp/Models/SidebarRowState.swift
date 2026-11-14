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

    init?(phase: TransferController.Phase, percent: Int?) {
        switch phase {
        case .starting, .connecting: kind = .connecting
        case .waiting: kind = .waiting
        case .confirmSend, .incoming: kind = .review
        case .transferring: kind = .transferring
        case .idle, .done, .stored, .failed: return nil
        }
        self.percent = kind == .transferring ? percent : nil
    }

    static func percent(of progress: TransferProgress?) -> Int? {
        guard let progress, progress.totalSize > 0, !progress.isBundling else { return nil }
        let done = Double(progress.bytesFinished + progress.fileSent)
        return min(100, max(0, Int((done / Double(progress.totalSize) * 100).rounded())))
    }
}
