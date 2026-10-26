import Foundation

/// Transfer speed from progress ticks: an exponential moving average (0.25
/// new, 0.75 old) over the deltas of the bytes done, sampled at most every
/// 0.2 s.
struct TransferSpeed {
    private(set) var bytesPerSecond: Double = 0
    private var lastBytes: Int64 = 0
    private var lastDate: Date?

    /// `doneBytes` is the transfer's running total (`bytesFinished + fileSent`).
    mutating func record(_ doneBytes: Int64, at now: Date = Date()) {
        guard let last = lastDate else {
            lastDate = now
            lastBytes = doneBytes
            return
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0.2 else { return }
        let instant = Double(doneBytes - lastBytes) / dt
        bytesPerSecond = bytesPerSecond == 0 ? instant : 0.25 * instant + 0.75 * bytesPerSecond
        lastDate = now
        lastBytes = doneBytes
    }
}
