import CrocKit
import SwiftUI

/// Settings > Advanced: croc's network and performance options.
/// The defaults are croc's own and right for most people. Every control shows
/// its default, says which side it affects and whether the other device has to
/// match, and checks its value inline by asking the engine
/// (`AdvancedSettingsValidation.swift`). A page pushed from the iOS settings
/// screen, a tab in the macOS Settings window.
struct AdvancedSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Network") {
                AdvancedRow(
                    footnote:
                        "Sends this device's connections, and Send as Link, through a SOCKS5 proxy, which wins over the HTTP proxy if both are set. Your local network skips it, and the address, with any password in it, is saved in the Keychain.",
                    error: AppSettings.socks5ProxyError(settings.socks5Proxy),
                    notSaved: settings.unsavedSecrets.contains(.socks5Proxy)
                ) {
                    LabeledField("SOCKS5 Proxy") {
                        TextField(
                            "SOCKS5 Proxy", text: $settings.socks5Proxy,
                            prompt: Text("None, or host:port")
                        )
                        .urlEntry()
                    }
                }
                AdvancedRow(
                    footnote:
                        "Sends this device's connections, and Send as Link, through an HTTP proxy, unless a SOCKS5 proxy is set. Your local network skips it, and the address, with any password in it, is saved in the Keychain.",
                    error: AppSettings.httpProxyError(settings.httpProxy),
                    notSaved: settings.unsavedSecrets.contains(.httpProxy)
                ) {
                    LabeledField("HTTP Proxy") {
                        TextField(
                            "HTTP Proxy", text: $settings.httpProxy,
                            prompt: Text("None, or host:port")
                        )
                        .urlEntry()
                    }
                }
                AdvancedRow(
                    footnote:
                        "Both devices need the same address to find each other on the local network, and blank uses \(AppSettings.advancedDefaults.multicastAddress).",
                    error: AppSettings.multicastAddressError(settings.multicastAddress)
                ) {
                    LabeledField("Multicast Address") {
                        TextField(
                            "Multicast Address", text: $settings.multicastAddress,
                            prompt: Text(AppSettings.advancedDefaults.multicastAddress)
                        )
                        .addressEntry()
                    }
                }
                AdvancedRow(
                    footnote:
                        "When receiving, connects straight to the sender at this address and base port (9009 unless changed), skipping relays.",
                    error: AppSettings.senderIPError(settings.peerIP)
                ) {
                    LabeledField("Sender IP") {
                        TextField(
                            "Sender IP", text: $settings.peerIP,
                            prompt: Text("Find the sender automatically")
                        )
                        .addressEntry()
                    }
                }
            }

            Section("Connection") {
                AdvancedRow(
                    footnote: settings.onlyLocal
                        ? "Turn off Local Network Only to use this. It is in Settings."
                        : "Skips finding the other device on your local network, so a transfer goes through a relay. Applies to sending and receiving."
                ) {
                    Toggle("Skip Local Network", isOn: $settings.disableLocal)
                        .disabled(settings.onlyLocal)
                }
                AdvancedRow(
                    footnote:
                        "Looks up a relay's address by asking 18 public DNS servers (Cloudflare, Google, Quad9, Comodo and OpenDNS) at once, in plain text. This skips your system, VPN and encrypted DNS settings and tells them the relay's name. It does not apply through a proxy or to Send as Link."
                ) {
                    Toggle("Built-in DNS Resolver", isOn: $settings.internalDNS)
                }
            }

            Section("Performance") {
                AdvancedRow(
                    footnote:
                        "Affects sending only: moves the data over one connection instead of several. This can be slower."
                ) {
                    Toggle("Single Connection", isOn: $settings.noMultiplexing)
                }
                AdvancedRow(
                    footnote:
                        "The most this device sends per second, such as 500k, 2m or 1g.",
                    error: AppSettings.throttleError(settings.throttleUpload)
                ) {
                    LabeledField("Send Speed Limit") {
                        TextField(
                            "Send Speed Limit", text: $settings.throttleUpload,
                            prompt: Text("No limit")
                        )
                        .addressEntry()
                    }
                }
            }

            Section("Exclude from sends") {
                AdvancedRow(
                    footnote:
                        "Leaves out these exact paths, one per line, relative to the folder you send, such as src/secret.txt. The patterns in Settings match any part of a name instead.",
                    error: AppSettings.excludePathsError(settings.excludePaths)
                ) {
                    LabeledField("Exact Paths") {
                        TextField(
                            "Exact Paths", text: $settings.excludePaths,
                            prompt: Text("One path per line"), axis: .vertical
                        )
                        .lineLimit(3...6)
                        .urlEntry()
                    }
                }
            }

            Section {
                Button {
                    confirmReset = true
                } label: {
                    Text("Reset to Defaults").hitTarget()
                }
                .buttonVariant(.plain)
                .disabled(settings.advancedIsDefault)
            } footer: {
                Text(
                    "Puts every setting on this page back to croc's default, clears the excluded paths and removes the saved proxies."
                )
                .foregroundStyle(Color.textSecondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .confirmationDialog(
            "Reset all Advanced settings?", isPresented: $confirmReset, titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) { settings.resetAdvancedToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes the saved proxies.")
        }
    }
}

/// One setting: the control, its inline error (words and an icon, never colour
/// alone), then a footnote on which side it affects.
private struct AdvancedRow<Content: View>: View {
    let footnote: LocalizedStringKey
    var error: String?
    /// The value's Keychain write failed (`AppSettings.unsavedSecrets`).
    var notSaved = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            content
                .accessibilityHint(error.map { Text(verbatim: $0) } ?? Text(footnote))
            if let error {
                StatusBanner(kind: .error, title: error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if notSaved {
                StatusBanner(
                    kind: .error, title: AppSettings.secretNotSavedTitle,
                    detail: AppSettings.secretNotSavedDetail
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(footnote)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.space2)
    }
}

/// A visible label above a text field, stacked so it reads the same at every
/// Dynamic Type size and on both platforms. The field keeps its own title as
/// its accessibility label.
private struct LabeledField<Field: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var field: Field

    init(_ title: LocalizedStringKey, @ViewBuilder field: () -> Field) {
        self.title = title
        self.field = field()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Text(title).accessibilityHidden(true)
            field
                .labelsHidden()
                .autocorrectionDisabled()
                .frame(
                    maxWidth: .infinity, minHeight: ControlHeight.hitTargetMin, alignment: .leading)
        }
    }
}

extension View {
    /// A host or URL field: no autocapitalization or autocorrection, and the
    /// URL keyboard. Shared with the relay and link server fields.
    func urlEntry() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }

    fileprivate func addressEntry() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never).keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }
}

#Preview {
    NavigationStack { AdvancedSettingsView() }
        .environment(
            AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore()))
}
