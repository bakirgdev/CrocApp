import Accessibility
import CrocKit
import SwiftUI

/// The accept gate. design/components.md → AcceptGate: a phase of the transfer
/// screen, not a sheet or an alert. Its answers (Decline says no to the other
/// device, Accept, or Keep Both and Replace when a name is taken, says yes) are
/// in the screen's actions row, so they stay in view above a long list. Leaving
/// answers nothing, and there is no Cancel here. The direction header sits above
/// it, in the screen's header.
struct IncomingRequestView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let list: FileList
    let conflicts: [String]
    let blocked: [String]

    private var summary: String {
        inflected(
            AttributedString(
                localized:
                    "^[\(list.files.count) file](inflect: true) • \(list.totalSize.formatted(.byteCount(style: .file)))"
            ))
    }

    var body: some View {
        VStack(spacing: 16) {
            GroupBox {
                VStack(spacing: 0) {
                    ForEach(Array(list.files.enumerated()), id: \.element.name) {
                        index, entry in
                        FileRow(name: entry.name, size: entry.size)
                        if index < list.files.count - 1 { Divider() }
                    }
                }
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if !blocked.isEmpty {
                StatusBanner(
                    kind: .error,
                    title: String(localized: "Blocked: unsafe file names in this transfer."))
            } else if !conflicts.isEmpty {
                // The conflict scan reports after the gate is up, so this
                // banner arrives on its own.
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "Some names are already taken"),
                    detail: inflected(
                        AttributedString(
                            localized:
                                "^[\(conflicts.count) item](inflect: true) in this transfer share a name with a file here. Keep Both saves the new ones under a new name; Replace overwrites them and resumes partly received files."
                        ))
                )
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .default, value: conflicts.isEmpty
        )
        // A phase change moves no VoiceOver focus, so say what arrived
        // (principles.md → Accessibility). Low priority queues it behind
        // the blocked banner's own announcement instead of cutting it off.
        .onAppear {
            var message = AttributedString(
                String(localized: "Files are waiting for your answer") + ". " + summary)
            message.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(message).post()
        }
    }
}
