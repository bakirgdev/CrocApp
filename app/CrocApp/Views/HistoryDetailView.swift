import SwiftData
import SwiftUI

/// One record, opened from History. A grouped `Form` titled by the row's
/// title: the status, the rows the record holds, the file names, then the
/// actions the context menu offers. A row appears only when the record holds
/// what it shows. design/components.md → HistoryRow, "Detail".
struct HistoryDetailView: View {
    let record: TransferRecord
    let actions: HistoryActions
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(HistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss

    @State private var resendUnavailable = false
    @State private var revokeCandidate: TransferRecord?
    @State private var deleteCandidate: TransferRecord?
    /// The record is deleted once this screen is gone, not while it is up: a
    /// deleted model read by a screen still on display is a crash.
    @State private var deleteWhenClosed = false

    private var isRevoking: Bool { actions.isRevoking(record) }
    /// A pruned or deleted record has no context. Reading any of its
    /// properties after that is a crash, so nothing below renders for it.
    private var isGone: Bool { record.modelContext == nil }

    var body: some View {
        Group {
            if isGone {
                Color.clear
            } else {
                form
            }
        }
        .onChange(of: isGone, initial: true) { _, gone in
            if gone { dismiss() }
        }
        .recordDialogs(
            revokeCandidate: $revokeCandidate, deleteCandidate: $deleteCandidate,
            resendUnavailable: $resendUnavailable, actions: actions, onDelete: { _ in delete() }
        )
        .onDisappear {
            if deleteWhenClosed { history.delete(record) }
        }
    }

    private var form: some View {
        Form {
            summarySection
            if !record.names.isEmpty { fileNamesSection }
            actionsSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: LayoutCap.contentMaxWidth)
        .navigationTitle(record.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var summarySection: some View {
        Section {
            Label {
                Text(record.status.statusTitle)
            } icon: {
                // The word beside it carries the status.
                Image(systemName: record.status.symbolName)
                    .foregroundStyle(record.status.glyphColor)
                    .accessibilityHidden(true)
            }
            valueRow("Direction") { Text(record.directionTitle) }
            valueRow("Date") { Text(record.date, format: Self.dateTime) }
            if record.totalBytes > 0 {
                valueRow("Size") { Text(record.totalBytes.formatted(.byteCount(style: .file))) }
            }
            if !record.isText, record.fileCount > 0 {
                valueRow("Files") { Text(record.fileCount, format: .number) }
            }
            if !record.codeHint.isEmpty {
                // A stored send's hint is the link server's host.
                let label: LocalizedStringKey = record.storedID == nil ? "Code Hint" : "Link Server"
                valueRow(label) { Text(record.codeHint).monospaced().privacySensitive() }
            }
            linkRow
        }
    }

    /// A label and its value. The value takes `Color.textSecondary`: the
    /// system's own secondary style is 3.44:1 (principles.md → Contrast, rule 4).
    private func valueRow(
        _ label: LocalizedStringKey, @ViewBuilder value: () -> some View
    ) -> some View {
        LabeledContent(label) { value().foregroundStyle(Color.textSecondary) }
    }

    /// A stored send's link: when it was revoked, else when it expires.
    @ViewBuilder private var linkRow: some View {
        if record.storedID != nil {
            if let revokedAt = record.revokedAt {
                valueRow("Revoked") { Text(revokedAt, format: Self.dateTime) }
            } else if let expiresAt = record.expiresAt {
                // The expiry passes while the screen is open.
                TimelineView(.everyMinute) { context in
                    let label: LocalizedStringKey = expiresAt > context.date ? "Expires" : "Expired"
                    valueRow(label) { Text(expiresAt, format: Self.dateTime) }
                }
            }
        }
    }

    private static let dateTime = Date.FormatStyle(date: .abbreviated, time: .shortened)

    private var fileNamesSection: some View {
        Section("File names") {
            ForEach(Array(record.names.enumerated()), id: \.offset) { _, name in
                Text(name)
            }
            // A record keeps at most `TransferRecord.maxNames` names.
            let unlisted = record.fileCount - record.names.count
            if unlisted > 0 {
                Text("+ \(unlisted) more").foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            if record.canResend {
                Button {
                    resendUnavailable = !actions.resend(record, router: router)
                } label: {
                    Text("Send Again").frame(maxWidth: .infinity)
                }
                .buttonVariant(.secondary)
            }
            if controller.canRevoke(record) {
                Button(role: .destructive) {
                    revokeCandidate = record
                } label: {
                    revokeLabel.frame(maxWidth: .infinity)
                }
                .buttonVariant(.destructiveTinted)
                .disabled(isRevoking)
            }
            Button(role: .destructive, action: requestDelete) {
                Text("Delete").frame(maxWidth: .infinity)
            }
            .buttonVariant(.destructiveTinted)
            .disabled(isRevoking)
        }
        .controlSize(.large)
    }

    /// components.md → States, loading: a working button keeps its label and
    /// swaps its leading glyph for a spinner.
    private var revokeLabel: some View {
        HStack(spacing: Spacing.space3) {
            if isRevoking { ProgressView().controlSize(.small) }
            Text("Revoke Link")
        }
    }

    /// A record with a link that still works asks first (HistoryView does
    /// the same for the list's paths).
    private func requestDelete() {
        if controller.canRevoke(record) {
            deleteCandidate = record
        } else {
            delete()
        }
    }

    private func delete() {
        deleteWhenClosed = true
        dismiss()
    }
}
