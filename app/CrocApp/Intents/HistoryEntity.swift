import AppIntents
import Foundation
import SwiftData

/// A past transfer as Shortcuts sees it: file names, direction,
/// status, date and size. Never the code phrase and never the code hint
/// (`docs/knowledge/app-ui-architecture.md`, "System surfaces"), so nothing a bystander could
/// reuse leaves the History screen.
///
/// The id is the record's `uuid`. Shortcuts saved by 1.3.0 and earlier hold
/// its SwiftData identifier instead (`HistoryEntityID`), which still finds it.
struct HistoryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Transfer")
    static let defaultQuery = HistoryEntityQuery()

    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Direction")
    var direction: HistoryDirection

    @Property(title: "Status")
    var status: HistoryStatus

    @Property(title: "Date")
    var date: Date

    @Property(title: "File Names")
    var fileNames: [String]

    @Property(title: "Size")
    var size: Measurement<UnitInformationStorage>

    /// The line under the name: direction, a status that is not the usual
    /// one, and the size when there is one. `3 files • 24 MB` is the result
    /// screen's separator (`design/voice.md`, "Numbers").
    let summary: String

    init(
        id: String, isSend: Bool, status: TransferRecord.Status, isText: Bool, fileCount: Int,
        totalBytes: Int64, names: [String], date: Date
    ) {
        let direction: HistoryDirection = isSend ? .sent : .received
        var parts = [String(localized: direction.title)]
        if status != .completed { parts.append(status.statusTitle) }
        if totalBytes > 0 { parts.append(totalBytes.formatted(.byteCount(style: .file))) }
        // The wrapped properties below are set through accessors, which need
        // every plain stored property in place first.
        self.id = id
        self.summary = parts.joined(separator: " • ")
        self.name = TransferRecord.name(
            isSend: isSend, isText: isText, fileCount: fileCount, names: names)
        self.direction = direction
        self.status = HistoryStatus(status)
        self.date = date
        self.fileNames = names
        self.size = Measurement(value: Double(totalBytes), unit: .bytes)
    }

    /// nil for a record the backfill has not reached yet (`HistoryStore`),
    /// which only a failed backfill leaves.
    @MainActor
    init?(record: TransferRecord) {
        guard let uuid = record.uuid else { return nil }
        self.init(
            id: uuid.uuidString, isSend: record.isSend, status: record.status,
            isText: record.isText,
            fileCount: record.fileCount, totalBytes: record.totalBytes, names: record.names,
            date: record.date)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(String.LocalizationValue(name)),
            subtitle: LocalizedStringResource(String.LocalizationValue(summary)),
            image: .init(systemName: direction.symbol))
    }

    /// Whether `text` appears in the name or in any file name, the way Finder
    /// matches: case, diacritics and width ignored.
    func matches(_ text: String) -> Bool {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return name.localizedStandardContains(needle)
            || fileNames.contains { $0.localizedStandardContains(needle) }
    }
}

nonisolated enum HistoryDirection: String, AppEnum {
    case sent, received

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Direction")
    // The metadata exporter reads these as literals: keep them literal, and in
    // step with `title`.
    static let caseDisplayRepresentations: [HistoryDirection: DisplayRepresentation] = [
        .sent: "Sent",
        .received: "Received",
    ]

    var title: LocalizedStringResource {
        switch self {
        case .sent: "Sent"
        case .received: "Received"
        }
    }

    var symbol: String {
        switch self {
        case .sent: "arrow.up.circle"
        case .received: "arrow.down.circle"
        }
    }
}

nonisolated enum HistoryStatus: String, AppEnum {
    case completed, failed, cancelled, declined

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Status")
    // The metadata exporter reads these as literals: keep them literal, and in
    // step with `TransferRecord.Status.statusTitle`.
    static let caseDisplayRepresentations: [HistoryStatus: DisplayRepresentation] = [
        .completed: "Completed",
        .failed: "Failed",
        .cancelled: "Cancelled",
        .declined: "Declined",
    ]

    init(_ status: TransferRecord.Status) {
        switch status {
        case .completed: self = .completed
        case .failed: self = .failed
        case .cancelled: self = .cancelled
        case .declined: self = .declined
        }
    }

}

/// The entity id 1.3.0 and earlier gave a record: its SwiftData identifier,
/// JSON-encoded. A saved shortcut can still hold one, and it finds its record
/// while the store that wrote it lasts.
nonisolated enum HistoryEntityID {
    /// nil for text that is not such an id: a `uuid`, or whatever else
    /// Shortcuts kept.
    static func identifier(from string: String) -> PersistentIdentifier? {
        try? JSONDecoder().decode(PersistentIdentifier.self, from: Data(string.utf8))
    }
}
