import CrocKit
import SwiftData
import SwiftUI

/// Local transfer history: a flat list, newest first, that opens a record in
/// `HistoryDetailView`. Send Again re-stages a past send's files via
/// AppRouter (same path as dock drops); records whose files vanished get an
/// explanatory alert instead of a silent no-op. Stored uploads show when
/// their link expires and can be revoked here. design/components.md →
/// HistoryRow.
struct HistoryView: View {
    @Environment(TransferController.self) private var controller
    @Environment(AppRouter.self) private var router
    @Environment(HistoryStore.self) private var history
    @Environment(AppSettings.self) private var settings
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    @State private var actions = HistoryActions()
    @State private var query = ""
    @State private var confirmClear = false
    @State private var resendUnavailable = false
    @State private var revokeCandidate: TransferRecord?
    @State private var deleteCandidate: TransferRecord?
    #if os(macOS)
    /// The selected row, which the Delete key removes.
    @State private var selection: PersistentIdentifier?
    /// The record whose detail is pushed.
    @State private var opened: PersistentIdentifier?
    #endif

    private var shown: [TransferRecord] { records.filter { $0.matches(search: query) } }

    var body: some View {
        content
            .navigationTitle("History")
            .toolbar {
                if !records.isEmpty {
                    Button("Clear History") { confirmClear = true }
                }
            }
            .confirmationDialog(
                "Clear all history?", isPresented: $confirmClear, titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { history.clear() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the list, not the files you received.")
            }
            .recordDialogs(
                revokeCandidate: $revokeCandidate, deleteCandidate: $deleteCandidate,
                resendUnavailable: $resendUnavailable, actions: actions, onDelete: delete)
    }

    @ViewBuilder private var content: some View {
        if records.isEmpty {
            emptyState
        } else {
            list
                .searchable(text: $query, prompt: "Search file names")
                .overlay {
                    if shown.isEmpty { ContentUnavailableView.search(text: query) }
                }
        }
    }

    /// components.md → HistoryRow: an empty list is an EmptyState. With Save
    /// Transfer History off it says so instead of promising rows that never come.
    @ViewBuilder private var emptyState: some View {
        if settings.saveTransferHistory {
            ContentUnavailableView {
                Label("No transfers yet", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Finished sends and receives appear here.")
                    .foregroundStyle(Color.textSecondary)
            } actions: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.space4) { emptyStateActions }
                    VStack(spacing: Spacing.space4) { emptyStateActions }
                }
            }
        } else {
            ContentUnavailableView {
                Label("History is off", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("Turn on Save Transfer History in Settings to list finished transfers here.")
                    .foregroundStyle(Color.textSecondary)
            } actions: {
                Button("Open Settings") { showSettings() }
                    .buttonVariant(.prominent)
            }
        }
    }

    @ViewBuilder private var emptyStateActions: some View {
        Button("Send") { router.openSend(with: []) }
            .buttonVariant(.prominent)
        Button("Receive") { router.openReceive() }
            .buttonVariant(.secondary)
    }

    #if os(macOS)
    /// A click selects, so the Delete key has a target. Double-click or
    /// Return opens the record, as in any Mac list. The context menu is the
    /// selection's, so a right-click on a row acts on that row.
    private var list: some View {
        List(selection: $selection) {
            ForEach(shown) { HistoryRow(record: $0, isRevoking: actions.isRevoking($0)) }
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            // Selection is single, so this is one row or none; a menu for
            // several rows would have to say what it acts on.
            if ids.count == 1, let record = record(in: ids) { menu(for: record) }
        } primaryAction: { ids in
            opened = ids.first
        }
        .onDeleteCommand {
            guard let record = record(in: selection.map { [$0] } ?? []),
                !actions.isRevoking(record)
            else { return }
            requestDelete(record)
        }
        .onChange(of: query) { selection = nil }
        .navigationDestination(item: $opened) { id in
            if let record = record(in: [id]) {
                HistoryDetailView(record: record, actions: actions)
            } else {
                // Deleted while open: leave the destination instead of
                // showing an empty screen.
                Color.clear.onAppear { opened = nil }
            }
        }
        .frame(maxWidth: LayoutCap.contentMaxWidth)
    }

    /// A row that is on screen: a hidden row (filtered out by the search)
    /// is never the target of a key press or a menu.
    private func record(in ids: some Collection<PersistentIdentifier>) -> TransferRecord? {
        shown.first { ids.contains($0.persistentModelID) }
    }
    #else
    private var list: some View {
        List {
            ForEach(shown) { record in
                // Not a value link: the stack that hosts this screen has a
                // homogeneous `AppRouter.Route` path, which a value of any
                // other type cannot join.
                NavigationLink {
                    HistoryDetailView(record: record, actions: actions)
                } label: {
                    HistoryRow(record: record, isRevoking: actions.isRevoking(record))
                }
                .contextMenu { menu(for: record) }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { requestDelete(record) }
                        .disabled(actions.isRevoking(record))
                    if controller.canRevoke(record) {
                        Button("Revoke") { revokeCandidate = record }
                            .tint(Color.statusError)
                            .disabled(actions.isRevoking(record))
                    }
                }
                .swipeActions(edge: .leading) {
                    if record.canResend {
                        Button("Send Again") { resend(record) }.tint(Color.accentSolid)
                    }
                }
            }
        }
        .frame(maxWidth: LayoutCap.contentMaxWidth)
    }
    #endif

    /// The context menu: always additive, every action is also in the detail.
    @ViewBuilder private func menu(for record: TransferRecord) -> some View {
        if record.canResend {
            Button("Send Again") { resend(record) }
        }
        if controller.canRevoke(record) {
            Button("Revoke Link", role: .destructive) { revokeCandidate = record }
                .disabled(actions.isRevoking(record))
        }
        Button("Delete", role: .destructive) { requestDelete(record) }
            .disabled(actions.isRevoking(record))
    }

    /// A record with a link that still works asks first, so the files do not
    /// outlive the only row that can revoke them. Any other record goes at once.
    private func requestDelete(_ record: TransferRecord) {
        if controller.canRevoke(record) {
            deleteCandidate = record
        } else {
            delete(record)
        }
    }

    private func delete(_ record: TransferRecord) {
        #if os(macOS)
        if selection == record.persistentModelID { selection = nil }
        #endif
        history.delete(record)
    }

    private func showSettings() {
        #if os(macOS)
        openSettings()
        #else
        router.push([.settings])
        #endif
    }

    private func resend(_ record: TransferRecord) {
        resendUnavailable = !actions.resend(record, router: router)
    }
}

/// One past transfer. design/components.md → HistoryRow.
private struct HistoryRow: View {
    let record: TransferRecord
    let isRevoking: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // components.md → HistoryRow: direction glyph at --icon-size-md, scaled.
    @ScaledMetric(relativeTo: .title3) private var glyphSize: CGFloat = IconSize.medium

    private static let titleLines = 1
    /// At accessibility sizes the title wraps instead of truncating.
    private static let largeTextTitleLines = 3

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
            .accessibilityLabel(record.directionTitle)
            .foregroundStyle(record.status == .completed ? Color.accentFill : Color.textSecondary)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(record.title)
                .lineLimit(isLargeText ? Self.largeTextTitleLines : Self.titleLines)
                .truncationMode(.middle)
            let layout =
                isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.space1))
                : AnyLayout(HStackLayout(spacing: Spacing.space3))
            layout {
                DateText(record.date)
                if record.totalBytes > 0 {
                    Text(record.totalBytes.formatted(.byteCount(style: .file)))
                }
                if !record.codeHint.isEmpty {
                    Text(record.codeHint).monospaced().privacySensitive()
                }
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            if isRevoking {
                HStack(spacing: Spacing.space3) {
                    ProgressView().controlSize(.small)
                    Text("Revoking link")
                }
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            } else if record.storedID != nil {
                // The link's expiry passes while the row is on screen.
                TimelineView(.everyMinute) { context in
                    if let linkState = record.linkState(now: context.date) {
                        Text(linkState)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The one place a status color appears without an adjacent word, so its
    /// accessibility label is the status word (components.md → HistoryRow).
    private var statusBadge: some View {
        Image(systemName: record.status.symbolName)
            .foregroundStyle(record.status.glyphColor)
            .accessibilityLabel(record.status.statusTitle)
    }
}

extension TransferRecord {
    /// The first file name plus how many more, "Text snippet", or a generic
    /// name when the record kept none.
    var title: String {
        if isText { return String(localized: "Text snippet") }
        guard let first = names.first else {
            return isSend ? String(localized: "Sent files") : String(localized: "Received files")
        }
        let extras = fileCount - 1
        return extras > 0
            ? String(
                localized: "\(first) + \(extras) more",
                comment:
                    "The first placeholder is a file name, the second how many other files the transfer had."
            ) : first
    }

    /// Past tense, because a record is a transfer that ended.
    var directionTitle: String {
        isSend ? String(localized: "Sent") : String(localized: "Received")
    }

    /// Where a stored upload's link stands. Revoked beats expired.
    func linkState(now: Date = .now) -> String? {
        guard storedID != nil else { return nil }
        if let revokedAt {
            return String(
                localized:
                    "Link revoked \(revokedAt.formatted(date: .abbreviated, time: .shortened))",
                comment: "The placeholder is the date and time the link was revoked.")
        }
        guard let expiresAt else { return nil }
        let when = expiresAt.formatted(date: .abbreviated, time: .shortened)
        return expiresAt > now
            ? String(
                localized: "Link expires \(when)",
                comment: "The placeholder is the date and time the link stops working.")
            : String(
                localized: "Link expired \(when)",
                comment: "The placeholder is the date and time the link stopped working.")
    }
}

extension TransferRecord.Status {
    /// The status as a word: the glyph's accessibility label and the detail's
    /// status row.
    var statusTitle: String {
        switch self {
        case .completed: String(localized: "Completed")
        case .failed: String(localized: "Failed")
        case .cancelled: String(localized: "Cancelled")
        case .declined: String(localized: "Declined")
        }
    }

    /// design/iconography.md → App only: the history status glyphs.
    var symbolName: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "slash.circle"
        case .declined: "hand.raised.fill"
        }
    }

    /// A fill color for the glyph, never for text (colors.md → Contrast, rule 2).
    var glyphColor: Color {
        switch self {
        case .completed: Color.statusSuccess
        case .failed, .declined: Color.statusError
        case .cancelled: Color.textSecondary
        }
    }
}

/// The dialogs a record's actions raise, shared by the list and the detail:
/// the Revoke and Delete confirmations, the revoke failure, and the Send
/// Again alert. `onDelete` is each screen's own way of deleting a record.
private struct RecordDialogs: ViewModifier {
    @Binding var revokeCandidate: TransferRecord?
    @Binding var deleteCandidate: TransferRecord?
    @Binding var resendUnavailable: Bool
    let actions: HistoryActions
    let onDelete: (TransferRecord) -> Void
    @Environment(TransferController.self) private var controller
    @State private var revokeFailure: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Revoke this link?", isPresented: revokeDialogShown, presenting: revokeCandidate
            ) { record in
                Button("Revoke Link", role: .destructive) { revoke(record) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text(
                    "The files are deleted from the link server and the link stops working for everyone."
                )
            }
            .confirmationDialog(
                "Delete this record?", isPresented: deleteDialogShown, presenting: deleteCandidate
            ) { record in
                Button("Revoke Link and Delete", role: .destructive) { revokeThenDelete(record) }
                Button("Delete and Keep Link", role: .destructive) { onDelete(record) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text(
                    "The link still works. Revoke it to delete the files from the link server now, or they stay until it expires."
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

    private var revokeDialogShown: Binding<Bool> {
        Binding(get: { revokeCandidate != nil }, set: { if !$0 { revokeCandidate = nil } })
    }

    private var deleteDialogShown: Binding<Bool> {
        Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })
    }

    private var revokeFailureShown: Binding<Bool> {
        Binding(get: { revokeFailure != nil }, set: { if !$0 { revokeFailure = nil } })
    }

    private func revoke(_ record: TransferRecord) {
        Task { revokeFailure = await actions.revoke(record, with: controller) }
    }

    /// The record stays when the revoke fails, so the failure can be retried.
    private func revokeThenDelete(_ record: TransferRecord) {
        Task {
            revokeFailure = await actions.revoke(record, with: controller)
            if revokeFailure == nil { onDelete(record) }
        }
    }
}

extension View {
    func recordDialogs(
        revokeCandidate: Binding<TransferRecord?>, deleteCandidate: Binding<TransferRecord?>,
        resendUnavailable: Binding<Bool>, actions: HistoryActions,
        onDelete: @escaping (TransferRecord) -> Void
    ) -> some View {
        modifier(
            RecordDialogs(
                revokeCandidate: revokeCandidate, deleteCandidate: deleteCandidate,
                resendUnavailable: resendUnavailable, actions: actions, onDelete: onDelete))
    }
}
