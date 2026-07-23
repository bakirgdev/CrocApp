import SwiftUI
import SwiftData

/// F12: local transfer history. Re-send re-stages a past send's files via
/// AppRouter (same path as dock drops); records whose files vanished get an
/// explanatory alert instead of a silent no-op.
struct HistoryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HistoryStore.self) private var history
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    @State private var confirmClear = false
    @State private var resendUnavailable = false

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("No transfers yet",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Finished sends and receives appear here."))
            } else {
                List {
                    ForEach(records) { record in
                        HistoryRow(record: record)
                            .contextMenu {
                                if record.isSend && !record.isText && !record.bookmarks.isEmpty {
                                    Button("Send Again") { resend(record) }
                                }
                                Button("Delete", role: .destructive) { history.delete(record) }
                            }
                            #if os(iOS)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { history.delete(record) }
                            }
                            .swipeActions(edge: .leading) {
                                if record.isSend && !record.isText && !record.bookmarks.isEmpty {
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
        .alert("Those files aren't available anymore", isPresented: $resendUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The originals were moved or deleted since that transfer.")
        }
    }

    private func resend(_ record: TransferRecord) {
        let urls = record.bookmarks.compactMap { data -> URL? in
            var stale = false
            #if os(macOS)
            let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                               relativeTo: nil, bookmarkDataIsStale: &stale)
            #else
            let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            #endif
            guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isSend ? "arrow.up.circle" : "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(record.status == .completed ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
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
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel(record.statusRaw)
    }
}
