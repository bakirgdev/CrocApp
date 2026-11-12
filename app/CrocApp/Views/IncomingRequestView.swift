import Accessibility
import CrocKit
import QuickLook
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// The accept gate. design/components.md → AcceptGate: a phase of the transfer
/// screen, not a sheet or an alert. Decline says no to the other device, Accept
/// (or Keep Both and Replace when a name is taken) says yes. Leaving answers
/// nothing, and there is no Cancel here. The direction header and the trust
/// badge sit above it, in the screen's header.
struct IncomingRequestView: View {
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let list: FileList
    let conflicts: [String]
    let blocked: [String]
    @ScaledMetric private var listMaxHeight = TransferStatusView.fileListMaxHeight

    private var summary: String {
        inflected(
            AttributedString(
                localized:
                    "^[\(list.files.count) file](inflect: true) • \(list.totalSize.formatted(.byteCount(style: .file)))"
            ))
    }

    var body: some View {
        VStack(spacing: Spacing.space5) {
            ScrollView {
                // A card of rows: FileRow draws the first/last corner rounding
                // and the separators.
                VStack(spacing: 0) {
                    ForEach(Array(list.files.enumerated()), id: \.element.name) { index, entry in
                        FileRow(
                            name: entry.name, size: entry.size,
                            isFirst: index == 0, isLast: index == list.files.count - 1)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: listMaxHeight)
            Text(summary)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
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
                .transition(.statusBannerInsert(reduceMotion: reduceMotion))
            }
            // Three labels do not fit side by side at accessibility text sizes
            // on a phone, so they stack there.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.space5) { actions }
                VStack(spacing: Spacing.space3) { actions }
            }
        }
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: conflicts.isEmpty
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

    @ViewBuilder private var actions: some View {
        Button("Decline", role: .destructive) { controller.respond(accept: false) }
            .buttonVariant(.destructive)
            .controlSize(.large)
        if blocked.isEmpty, !conflicts.isEmpty {
            Button("Replace") { controller.respond(accept: true, policy: .replace) }
                .buttonVariant(.secondary)
                .controlSize(.large)
            Button("Keep Both") { controller.respond(accept: true, policy: .keepBoth) }
                .buttonVariant(.prominent)
                .controlSize(.large)
        } else {
            // Until the conflict scan reports, Accept keeps both: it
            // never overwrites a file the scan has not shown yet.
            Button("Accept") { controller.respond(accept: true, policy: .keepBoth) }
                .buttonVariant(.prominent)
                .controlSize(.large)
                .disabled(!blocked.isEmpty)
        }
    }
}
