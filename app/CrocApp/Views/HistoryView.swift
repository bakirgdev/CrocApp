import CrocKit
import SwiftData
import SwiftUI

/// Local transfer history. Re-send re-stages a past send's files via
/// AppRouter (same path as dock drops); records whose files vanished get an
/// explanatory alert instead of a silent no-op. Stored uploads show when
/// their link expires and can be revoked here.
struct HistoryView: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(HistoryStore.self) private var history
    @Environment(AppSettings.self) private var settings
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    @State private var confirmClear = false
    @State private var resendUnavailable = false
    @State private var revokeCandidate: TransferRecord?
    @State private var revokeFailure: String?

    var body: some View {
        Group {
            if records.isEmpty, !settings.saveTransferHistory {
                // components.md → HistoryRow: with Save Transfer History off the
                // empty list says so instead of promising rows that never come.
                ContentUnavailableView {
                    Label("History is off", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(
                        "Turn on Save Transfer History in Settings to list finished transfers here."
                    )
                } actions: {
                    Button("Open Settings") { showSettings() }
                        .buttonVariant(.prominent)
                }
            } else if records.isEmpty {
                ContentUnavailableView {
                    Label("No transfers yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Finished sends and receives appear here.")
                } actions: {
                    HStack(spacing: Spacing.space4) {
                        Button("Send") { router.openSend(with: []) }
                            .buttonVariant(.prominent)
                        Button("Receive") { router.openReceive() }
                            .buttonVariant(.secondary)
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
                                Button("Revoke") { revokeCandidate = record }
                                .tint(Color.statusError)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if record.canResend {
                                Button("Send Again") { resend(record) }.tint(Color.accentFill)
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
            Text("Removes the list only. Received files stay where they are.")
        }
        .confirmationDialog(
            "Revoke this link?", isPresented: revokeDialogShown, presenting: revokeCandidate
        ) { record in
            Button("Revoke Link", role: .destructive) { revoke(record) }
        } message: { _ in
            Text(
                "The files are deleted from the link server and the link stops working for everyone."
            )
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

    private func showSettings() {
        #if os(macOS)
        openSettings()
        #else
        router.push([.settings])
        #endif
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
                revokeFailure =
                    TransferFailure(failure, situation: .init(isStored: true)).text
            } catch {
                revokeFailure = String(localized: "Try again in a moment.")
            }
        }
    }

    private func resend(_ record: TransferRecord) {
        // See SecurityScopedBookmark.resolveIfReachable for why the scope
        // must be started before the existence probe -- the send opens its
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
    // components.md → HistoryRow: direction glyph at --icon-size-md, scaled.
    @ScaledMetric(relativeTo: .title3) private var glyphSize: CGFloat = IconSize.medium

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isLargeText {
                // The glyph and badge sit above the text so it keeps the
                // full row width instead of a few characters per line.
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    HStack(spacing: Spacing.space4) {
                        directionGlyph
                        statusBadge
                    }
                    textColumn
                }
            } else {
                HStack(spacing: Spacing.space4) {
                    directionGlyph
                    textColumn
                    statusBadge
                }
            }
        }
        .padding(.vertical, Spacing.space1)
        .accessibilityElement(children: .combine)
    }

    private var directionGlyph: some View {
        Image(systemName: record.isSend ? "arrow.up.circle" : "arrow.down.circle")
            .font(.system(size: glyphSize))
            .accessibilityLabel(record.isSend ? "Sent" : "Received")
            .foregroundStyle(record.status == .completed ? Color.accentFill : Color.textSecondary)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(title)
                .lineLimit(isLargeText ? 3 : 1)
                .truncationMode(.middle)
            let layout =
                isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.space1))
                : AnyLayout(HStackLayout(spacing: Spacing.space3))
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
            return String(
                localized:
                    "Link revoked \(revokedAt.formatted(date: .abbreviated, time: .shortened))",
                comment: "The placeholder is the date and time the link was revoked.")
        }
        guard let expiresAt = record.expiresAt else { return nil }
        let when = expiresAt.formatted(date: .abbreviated, time: .shortened)
        return expiresAt > .now
            ? String(
                localized: "Link expires \(when)",
                comment: "The placeholder is the date and time the link stops working.")
            : String(
                localized: "Link expired \(when)",
                comment: "The placeholder is the date and time the link stopped working.")
    }

    private var title: String {
        if record.isText { return String(localized: "Text snippet") }
        guard let first = record.names.first else {
            return record.isSend
                ? String(localized: "Sent files") : String(localized: "Received files")
        }
        let extras = record.fileCount - 1
        return extras > 0
            ? String(
                localized: "\(first) + \(extras) more",
                comment:
                    "The first placeholder is a file name, the second how many other files the transfer had."
            ) : first
    }

    private var statusBadge: some View {
        Group {
            switch record.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.statusSuccess)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.statusError)
            case .cancelled:
                Image(systemName: "slash.circle").foregroundStyle(Color.textSecondary)
            case .declined:
                Image(systemName: "hand.raised.fill").foregroundStyle(Color.statusError)
            }
        }
        .accessibilityLabel(record.status.title)
    }
}

extension TransferRecord.Status {
    fileprivate var title: String {
        switch self {
        case .completed: String(localized: "Completed")
        case .failed: String(localized: "Failed")
        case .cancelled: String(localized: "Cancelled")
        case .declined: String(localized: "Declined")
        }
    }
}
