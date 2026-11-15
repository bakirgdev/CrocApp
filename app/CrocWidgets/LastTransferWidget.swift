import AppIntents
import SwiftUI
import WidgetKit

struct LastTransferEntry: TimelineEntry {
    let date: Date
    let snapshot: TransferSnapshot?
}

/// One entry from the snapshot file. The app reloads the timeline when the
/// file changes, so the policy is `.never`.
struct LastTransferProvider: TimelineProvider {
    private func entry() -> LastTransferEntry {
        LastTransferEntry(date: .now, snapshot: TransferSnapshotStore.shared?.read())
    }

    func placeholder(in context: Context) -> LastTransferEntry {
        LastTransferEntry(
            date: .now,
            snapshot: TransferSnapshot(
                direction: .send, outcome: .done, itemCount: 2, name: nil, date: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (LastTransferEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastTransferEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }
}

struct LastTransferWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LastTransfer", provider: LastTransferProvider()) { entry in
            LastTransferView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Transfer")
        .description("The state of your last transfer, with Send and Receive buttons.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LastTransferView: View {
    let snapshot: TransferSnapshot?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: 16) {
                status
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Button(intent: OpenSendIntent()) {
                        Label("Send", systemImage: "arrow.up.circle").frame(maxWidth: .infinity)
                    }
                    Button(intent: OpenReceiveIntent()) {
                        Label("Receive", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 140)
            }
        } else {
            status
        }
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let snapshot {
                Image(systemName: Self.symbol(snapshot.outcome))
                    .font(.title2)
                    .foregroundStyle(Self.color(snapshot.outcome))
                Text(Self.title(snapshot)).font(.headline)
                if let name = snapshot.name {
                    Text(verbatim: name).font(.subheadline).lineLimit(2)
                } else if snapshot.itemCount > 0 {
                    Text("^[\(snapshot.itemCount) file](inflect: true)")
                        .font(.subheadline)
                }
                Text(snapshot.date, style: .relative)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Image(systemName: "arrow.up.arrow.down.circle").font(.title2)
                    .foregroundStyle(.secondary)
                Text("No recent transfer").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    static func symbol(_ outcome: TransferSnapshot.Outcome) -> String {
        switch outcome {
        case .done: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .stopped: "stop.circle"
        }
    }

    static func color(_ outcome: TransferSnapshot.Outcome) -> Color {
        switch outcome {
        case .done: .green
        case .failed: .orange
        case .stopped: .secondary
        }
    }

    static func title(_ s: TransferSnapshot) -> LocalizedStringKey {
        switch (s.direction, s.outcome) {
        case (.send, .done): "Sent"
        case (.receive, .done): "Received"
        case (.send, .failed): "Send failed"
        case (.receive, .failed): "Receive failed"
        case (.send, .stopped): "Send stopped"
        case (.receive, .stopped): "Receive stopped"
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    LastTransferWidget()
} timeline: {
    LastTransferEntry(
        date: .now,
        snapshot: TransferSnapshot(
            direction: .receive, outcome: .done, itemCount: 1, name: "Report.pdf", date: .now))
    LastTransferEntry(date: .now, snapshot: nil)
}
