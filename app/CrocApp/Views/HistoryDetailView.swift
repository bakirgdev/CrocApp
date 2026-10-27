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
    /// The record is deleted once this screen is gone, not while it is up: a
    /// deleted model read by a screen still on display is a crash.
    @State private var deleteWhenClosed = false

    private var isRevoking: Bool { actions.isRevoking(record) }

    var body: some View {
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
        .recordDialogs(
            revokeCandidate: $revokeCandidate, resendUnavailable: $resendUnavailable,
            actions: actions
        )
        .onDisappear {
            if deleteWhenClosed { history.delete(record) }
        }
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
                valueRow(label) { Text(record.codeHint).monospaced() }
            }
            linkRow
        }
    }

    /// A label and its value. The value takes `Color.textSecondary`: the
    /// system's own secondary style is 3.44:1 (colors.md → Contrast, rule 4).
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
                let label: LocalizedStringKey = expiresAt > .now ? "Expires" : "Expired"
                valueRow(label) { Text(expiresAt, format: Self.dateTime) }
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
            Button(role: .destructive, action: delete) {
                Text("Delete").frame(maxWidth: .infinity)
            }
            .buttonVariant(.destructiveTinted)
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

    private func delete() {
        deleteWhenClosed = true
        dismiss()
    }
}
