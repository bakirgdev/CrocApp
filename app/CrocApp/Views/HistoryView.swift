import CrocKit
import SwiftData
import SwiftUI

/// F12: local transfer history. Re-send re-stages a past send's files via
/// AppRouter (same path as dock drops); records whose files vanished get an
/// explanatory alert instead of a silent no-op. Stored uploads (R19) show when
/// their link expires and can be revoked here.
struct HistoryView: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(HistoryStore.self) private var history
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    @State private var confirmClear = false
    @State private var resendUnavailable = false
    @State private var revokeCandidate: TransferRecord?
    @State private var revokeFailure: String?

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No transfers yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Finished sends and receives appear here.")
                } actions: {
                    HStack(spacing: Spacing.space4) {
                        Button("Send") { router.openSend(with: []) }
                            .buttonStyle(.borderedProminent)
                        Button("Receive") { router.openReceive() }
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                List {
                    ForEach(records) { record in
                        HistoryRow(record: record)
                            .contextMenu {
                                if record.canResend {
                                    Button("Send Again") { resend(record) }
                                }
                                if controller.canRevoke(record) {
                                    Button("Revoke Link", role: .destructive) {
                                        revokeCandidate = record
                                    }
                                }
                                Button("Delete", role: .destructive) { history.delete(record) }
                            }
                            #if os(iOS)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { history.delete(record) }
                            if controller.canRevoke(record) {
                                Button("Revoke") { revokeCandidate = record }.tint(.orange)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if record.canResend {
                                Button("Send Again") { resend(record) }.tint(.accentColor)
                            }
                        }
                            #endif
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !records.isEmpty {
                Button("Clear") { confirmClear = true }
                    .accessibilityLabel("Clear all history")
            }
        }
        .confirmationDialog("Clear all history?", isPresented: $confirmClear) {
            Button("Clear All", role: .destructive) { history.clear() }
        } message: {
            Text("Removes the list only — received files stay where they are.")
        }
        .confirmationDialog(
            "Revoke this link?", isPresented: revokeDialogShown, presenting: revokeCandidate
        ) { record in
            Button("Revoke Link", role: .destructive) { revoke(record) }
        } message: { _ in
            Text("The files are deleted from the server and the link stops working for everyone.")
        }
        .alert("Couldn't revoke the link", isPresented: revokeFailureShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(revokeFailure ?? "")
        }
        .alert("Those files aren't available anymore", isPresented: $resendUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The originals were moved or deleted since that transfer.")
        }
    }

    private var revokeDialogShown: Binding<Bool> {
        Binding(get: { revokeCandidate != nil }, set: { if !$0 { revokeCandidate = nil } })
    }

    private var revokeFailureShown: Binding<Bool> {
        Binding(get: { revokeFailure != nil }, set: { if !$0 { revokeFailure = nil } })
    }

    private func revoke(_ record: TransferRecord) {
        Task {
            do {
                try await controller.revoke(record)
            } catch let failure as EngineFailure {
                revokeFailure = TransferController.friendlyMessage(
                    for: failure, cancelRequested: false, declineRequested: false, stored: true)
            } catch {
                revokeFailure = "Try again in a moment."
            }
        }
    }

    private func resend(_ record: TransferRecord) {
        // See SecurityScopedBookmark.resolveIfReachable for why the scope
        // must be started before the existence probe -- startSend opens its
        // own scope at send time.
        let urls = record.bookmarks.compactMap { data in
            SecurityScopedBookmark.resolveIfReachable(data)
        }
        guard !urls.isEmpty else {
            resendUnavailable = true
            return
        }
        router.openSend(with: urls)
    }
}

private struct HistoryRow: View {
    let record: TransferRecord
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isLargeText {
                // The glyph and badge sit above the text so it keeps the
                // full row width instead of a few characters per line.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        directionGlyph
                        statusBadge
                    }
                    textColumn
                }
            } else {
                HStack(spacing: 12) {
                    directionGlyph
                    textColumn
                    statusBadge
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var directionGlyph: some View {
        Image(systemName: record.isSend ? "arrow.up.circle" : "arrow.down.circle")
            .font(.title3)
            .accessibilityLabel(record.isSend ? "Sent" : "Received")
            .foregroundStyle(record.status == .completed ? Color.accentColor : .secondary)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .lineLimit(isLargeText ? 3 : 1)
                .truncationMode(.middle)
            let layout =
                isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Text(record.date, format: .relative(presentation: .named))
                if record.totalBytes > 0 {
                    Text(record.totalBytes.formatted(.byteCount(style: .file)))
                }
                if !record.codeHint.isEmpty {
                    Text(record.codeHint).monospaced()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let linkState {
                Text(linkState)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Where a stored upload's link stands. Revoked beats expired.
    private var linkState: String? {
        guard record.storedID != nil else { return nil }
        if let revokedAt = record.revokedAt {
            return "Link revoked \(revokedAt.formatted(date: .abbreviated, time: .shortened))"
        }
        guard let expiresAt = record.expiresAt else { return nil }
        let when = expiresAt.formatted(date: .abbreviated, time: .shortened)
        return expiresAt > .now ? "Link expires \(when)" : "Link expired \(when)"
    }

    private var title: String {
        if record.isText { return "Text snippet" }
        guard let first = record.names.first else {
            return record.isSend ? "Sent files" : "Received files"
        }
        let extras = record.fileCount - 1
        return extras > 0 ? "\(first) + \(extras) more" : first
    }

    private var statusBadge: some View {
        Group {
            switch record.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .cancelled:
                Image(systemName: "slash.circle").foregroundStyle(.secondary)
            case .declined:
                Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
            }
        }
        .accessibilityLabel(record.status.title)
    }
}

extension TransferRecord.Status {
    fileprivate var title: String {
        switch self {
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .declined: "Declined"
        }
    }
}
