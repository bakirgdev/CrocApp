import CrocKit
import SwiftUI

/// Settings > Relay health: checks the relay the settings point at and the
/// local network, and says what to change (`RelayHealth`). Shown as a sheet from
/// the Relay section on every platform.
struct RelayHealthView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LocalNetworkChecker.self) private var localNetwork
    @Environment(\.dismiss) private var dismiss
    @State private var health: RelayHealth?

    var body: some View {
        Form {
            if let health {
                content(health)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Relay Health")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            let health = RelayHealth(settings: settings)
            self.health = health
            localNetwork.checkIfNeeded()
            // A proxy is set: wait for the user's say-so (`proxyNotice`).
            if !health.usesProxy { await health.run() }
        }
    }

    /// The check cannot use the Advanced proxies, so it needs a tap before it
    /// shows this device's address to the relays.
    @ViewBuilder private func proxyNotice(_ health: RelayHealth) -> some View {
        if health.usesProxy, health.rows.isEmpty {
            Section {
                StatusBanner(
                    kind: .warning,
                    title: String(localized: "This check doesn't use your proxy"),
                    detail: String(
                        localized:
                            "It connects to each relay directly, so every relay it tries sees this device's own address."
                    ))
                Button {
                    Task { await health.run() }
                } label: {
                    Text("Check Anyway").hitTarget()
                }
                .buttonVariant(.plain)
            }
        }
    }

    @ViewBuilder private func content(_ health: RelayHealth) -> some View {
        proxyNotice(health)
        if health.usesNoRelay {
            Section("Relay") {
                Text("Local Network Only is on, so transfers use no relay.")
                    .foregroundStyle(Color.textSecondary)
            }
        }
        ForEach(health.targets, id: \.self) { address in
            Section {
                ForEach(health.rows.filter { $0.address == address }) { row in
                    LabeledContent {
                        ProbeResult(result: row.result)
                    } label: {
                        Text(verbatim: row.family == .ipv4 ? "IPv4" : "IPv6")
                    }
                }
            } header: {
                Text(verbatim: address)
            }
        }
        Section("Local network") {
            LocalNetworkRow(status: localNetwork.status)
            if localNetwork.status == .denied {
                StatusBanner(
                    kind: .info, title: String(localized: "Local network access is off"),
                    detail: TransferStatusView.localNetworkDeniedDetail)
            }
        }
        verdict(health)
        Section {
            Button {
                localNetwork.recheckIfDenied()
                Task { await health.run() }
            } label: {
                Text("Check Again").hitTarget()
            }
            .buttonVariant(.plain)
            .disabled(health.isRunning || (health.usesProxy && health.rows.isEmpty))
        } footer: {
            Text(
                "The check connects to the relay and joins it the way a transfer does, without sending anything. It does not use a proxy."
            )
            .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder private func verdict(_ health: RelayHealth) -> some View {
        let advice = health.advice
        if !advice.isEmpty || health.isHealthy {
            Section {
                ForEach(advice, id: \.title) { failure in
                    StatusBanner(kind: .error, title: failure.title, detail: failure.detail)
                }
                if health.isHealthy {
                    StatusBanner(
                        kind: .success, title: String(localized: "The relay is working"),
                        detail: String(localized: "It answered and accepted the password."))
                }
            }
        }
    }
}

/// One probe's outcome in words and a glyph, never colour alone.
private struct ProbeResult: View {
    let result: RelayCheckResult?

    var body: some View {
        if let result {
            Label {
                Text(Self.text(result))
            } icon: {
                Image(systemName: Self.symbol(result.verdict))
            }
            .foregroundStyle(Color.textSecondary)
        } else {
            ProgressView().controlSize(.small).accessibilityLabel("Checking")
        }
    }

    private static func symbol(_ verdict: RelayCheckResult.Verdict) -> String {
        switch verdict {
        case .ok: "checkmark.circle"
        case .noAddress: "minus.circle"
        case .unreachable, .badPassword, .busy, .notARelay, .invalidAddress:
            "exclamationmark.circle"
        }
    }

    private static func text(_ result: RelayCheckResult) -> String {
        let latency = Measurement(value: result.latencyMs ?? 0, unit: UnitDuration.milliseconds)
            .formatted(
                .measurement(
                    width: .abbreviated, usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0))))
        return switch result.verdict {
        case .ok: String(localized: "Reachable in \(latency), password accepted")
        case .noAddress: String(localized: "No address of this kind")
        case .unreachable: String(localized: "Can't connect")
        case .badPassword: String(localized: "Reachable in \(latency), password rejected")
        case .busy: String(localized: "Reachable in \(latency), but the relay is busy")
        case .notARelay: String(localized: "Reachable, but not a croc relay")
        case .invalidAddress: String(localized: "Not an address with a port")
        }
    }
}

private struct LocalNetworkRow: View {
    let status: LocalNetworkChecker.Status

    var body: some View {
        LabeledContent("Access") {
            switch status {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle")
            case .denied:
                Label("Off", systemImage: "exclamationmark.circle")
            case .unknown:
                Label("Not checked yet", systemImage: "minus.circle")
            }
        }
        .foregroundStyle(Color.textSecondary)
    }
}

/// Opens the health check as a sheet; the same button sits beside the relay
/// settings that a failing check points at and the relay this Mac runs.
struct RelayHealthButton: View {
    @State private var isShown = false

    var body: some View {
        Button("Check Relay…") { isShown = true }
            .buttonVariant(.plain)
            .sheet(isPresented: $isShown) {
                NavigationStack { RelayHealthView() }
                    #if os(macOS)
                .frame(minWidth: 440, minHeight: 480)
                    #endif
            }
    }
}
