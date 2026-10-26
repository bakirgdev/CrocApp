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
                        "Applies to this device only. Takes priority over the HTTP proxy if both are set. Connections on your local network skip the proxy. Also used for Send as Link. Saved in the Keychain.",
                    error: AppSettings.socks5ProxyError(settings.socks5Proxy)
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
                        "Applies to this device only. Ignored when a SOCKS5 proxy is set. Connections on your local network skip the proxy. Also used for Send as Link. Saved in the Keychain.",
                    error: AppSettings.httpProxyError(settings.httpProxy)
                ) {
                    LabeledField("HTTP Proxy") {
                        TextField(
                            "HTTP Proxy", text: $settings.httpProxy,
                            prompt: Text("None, or host:port")
                        )
                        .urlEntry()
                    }
                }
                #if os(macOS)
                AdvancedRow(
                    footnote:
                        "Applies to both devices. They find each other on the local network only if both use the same address. Blank uses \(AppSettings.advancedDefaults.multicastAddress).",
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
                #endif
                AdvancedRow(
                    footnote:
                        "Applies when receiving. Connects straight to the sender at this address and port, skipping relays. Use the sender's base port, 9009 unless they changed it.",
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

            Section("Performance") {
                AdvancedRow(
                    footnote:
                        "Applies when sending. The most this device sends per second, such as 500k, 2m or 1g. The other device is not affected.",
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

            Section {
                Button("Reset to Defaults") { confirmReset = true }
                    .buttonVariant(.plain)
                    .disabled(settings.advancedIsDefault)
            } footer: {
                Text(
                    "Puts every setting on this page back to croc's default and removes the saved proxies."
                )
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
    let footnote: String
    var error: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            content
                .accessibilityHint(error ?? footnote)
            if let error {
                StatusBanner(kind: .error, title: error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
    fileprivate func urlEntry() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never).keyboardType(.URL)
        #else
        self
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
