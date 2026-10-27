import AppIntents
import CoreSpotlight
import Foundation
import OSLog
import SwiftData

/// A past transfer as Shortcuts and Spotlight see it: file names, direction,
/// status, date and size. Never the code phrase and never the code hint
/// (`design/platforms.md`, "System surfaces"), so nothing a bystander could
/// reuse leaves the History screen.
///
/// The id is the record's SwiftData identifier (`HistoryEntityID`), which
/// outlives a relaunch. Spotlight indexes the entity too (`IndexedEntity`),
/// through `HistoryEntityStore`.
struct HistoryEntity: AppEntity, IndexedEntity {
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
    /// screen's separator (`design/content.md`, "Numbers").
    let summary: String

    init(
        id: String, isSend: Bool, status: TransferRecord.Status, isText: Bool, fileCount: Int,
        totalBytes: Int64, names: [String], date: Date
    ) {
        let direction: HistoryDirection = isSend ? .sent : .received
        let status = HistoryStatus(status)
        var parts = [String(localized: direction.title)]
        if status != .completed { parts.append(String(localized: status.title)) }
        if totalBytes > 0 { parts.append(totalBytes.formatted(.byteCount(style: .file))) }
        // The wrapped properties below are set through accessors, which need
        // every plain stored property in place first.
        self.id = id
        self.summary = parts.joined(separator: " • ")
        self.name = Self.name(isSend: isSend, isText: isText, fileCount: fileCount, names: names)
        self.direction = direction
        self.status = status
        self.date = date
        self.fileNames = names
        self.size = Measurement(value: Double(totalBytes), unit: .bytes)
    }

    /// nil when the record has no id Shortcuts could hand back (never expected:
    /// a saved record always has one).
    @MainActor
    init?(record: TransferRecord) {
        guard let id = HistoryEntityID.string(for: record.persistentModelID) else { return nil }
        self.init(
            id: id, isSend: record.isSend, status: record.status, isText: record.isText,
            fileCount: record.fileCount, totalBytes: record.totalBytes, names: record.names,
            date: record.date)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(String.LocalizationValue(name)),
            subtitle: LocalizedStringResource(String.LocalizationValue(summary)),
            image: .init(systemName: direction.symbol))
    }

    /// Each file name is a keyword, so a search finds a transfer by any file in
    /// it, not just the first one the name shows.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = name
        attributes.displayName = name
        attributes.contentDescription = summary
        attributes.keywords = fileNames
        attributes.contentCreationDate = date
        return attributes
    }

    /// The History row's title (`design/components.md`, "HistoryRow"): the
    /// first file name plus "+ N more", or "Text snippet".
    static func name(isSend: Bool, isText: Bool, fileCount: Int, names: [String]) -> String {
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

    var title: LocalizedStringResource {
        switch self {
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .declined: "Declined"
        }
    }
}

/// The entity id of a record: its SwiftData identifier, JSON-encoded. Stable
/// for the life of the store, so a Spotlight entry or a saved shortcut still
/// finds its record after a relaunch. Not a format to rely on across an OS
/// update; `HistoryEntityStore` rebuilds the index at every launch, and an id
/// that no longer decodes finds nothing.
nonisolated enum HistoryEntityID {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "spotlight")

    static func string(for id: PersistentIdentifier) -> String? {
        do {
            return String(data: try JSONEncoder().encode(id), encoding: .utf8)
        } catch {
            log.error("entity id encode failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// nil for text that is not an id this store wrote: Shortcuts and
    /// Spotlight hand back whatever they kept, so an unknown id is expected.
    static func identifier(from string: String) -> PersistentIdentifier? {
        try? JSONDecoder().decode(PersistentIdentifier.self, from: Data(string.utf8))
    }
}
