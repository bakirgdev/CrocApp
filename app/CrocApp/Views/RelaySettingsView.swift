#if os(macOS)
import SwiftUI

/// Settings > Relay (Mac only): run a croc relay here, so devices on the same
/// network can use it as their relay. Off by default and never started without
/// the user's say-so (`RelayHostController`).
struct RelaySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(RelayHostController.self) private var relay
    @State private var addresses: [LocalAddresses.Address] = []

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "Run a Relay",
                    isOn: Binding(get: { relay.isRunning }, set: { relay.setRunning($0) }))
                if case .failed(let failure) = relay.state {
                    StatusBanner(kind: .error, title: failure.title, detail: failure.detail)
                }
                TextField(
                    "Port", value: $settings.relayHostPort,
                    format: .number.grouping(.never)
                )
                .disabled(relay.isRunning)
                if let error = AppSettings.relayHostPortError(settings.relayHostPort) {
                    StatusBanner(kind: .error, title: error)
                }
                SecureField("Password", text: $settings.relayHostPassword, prompt: Text("Default"))
                    .disabled(relay.isRunning)
                if settings.unsavedSecrets.contains(.relayHostPassword) {
                    StatusBanner(
                        kind: .error, title: AppSettings.secretNotSavedTitle,
                        detail: AppSettings.secretNotSavedDetail)
                }
                Toggle("Start Relay at Launch", isOn: $settings.relayHostAtLaunch)
            } header: {
                Text("Relay on this Mac")
            } footer: {
                Text(
                    "Other devices on your network can use this Mac as their relay while CrocApp runs. Without a password, anyone who can reach it can use it. The relay uses the port and the three after it, and stops when you quit CrocApp."
                )
                .foregroundStyle(Color.textSecondary)
            }

            if case .running(let ports) = relay.state {
                Section {
                    ForEach(addresses, id: \.ip) { address in
                        LabeledContent {
                            Text(verbatim: LocalAddresses.relayAddress(address, port: ports[0]))
                                .textSelection(.enabled)
                        } label: {
                            Text(verbatim: address.isIPv6 ? "IPv6" : "IPv4")
                            Text(verbatim: address.interface)
                        }
                    }
                    if addresses.isEmpty {
                        Text("This Mac has no active network address.")
                            .foregroundStyle(Color.textSecondary)
                    }
                } header: {
                    Text("Use on the other device")
                } footer: {
                    Text(
                        "Enter one as the relay address in CrocApp, or after --relay in croc. Allow ports \(Self.portText(ports.first)) to \(Self.portText(ports.last)) in a firewall if a device cannot connect."
                    )
                    .foregroundStyle(Color.textSecondary)
                }
            }

            Section {
                RelayHealthButton()
            } footer: {
                Text("Checks the relay your transfers use, and the local network.")
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 420)
        .onAppear { addresses = LocalAddresses.current() }
        .onChange(of: relay.state) { addresses = LocalAddresses.current() }
    }

    /// A port is not a quantity: no thousands separator.
    private static func portText(_ port: Int?) -> String {
        (port ?? 0).formatted(.number.grouping(.never))
    }
}
#endif
