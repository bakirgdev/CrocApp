import CrocKit
import SwiftUI

/// Power-option form sections (F13-F19), shared by the macOS Settings scene
/// and the iOS settings screen. Empty relay fields mean croc's defaults: with
/// no custom relay, the public relay pool.
struct PowerSettingsSections: View {
    @Environment(AppSettings.self) private var settings

    private static let connectionLockedReason =
        "Unavailable while Local Network Only is on: those transfers never use a relay."

    var body: some View {
        @Bindable var settings = settings

        Section("Relay") {
            TextField(
                "Address", text: $settings.relayAddress,
                prompt: Text("Public relay pool")
            )
            .autocorrectionDisabled()
            TextField(
                "IPv6 Address", text: $settings.relayAddress6,
                prompt: Text("Public relay pool")
            )
            .autocorrectionDisabled()
            SecureField(
                "Password", text: $settings.relayPassword,
                prompt: Text("Default")
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
        }

        Section {
            TextField(
                "Link Server", text: $settings.storedServer,
                prompt: Text(AppSettings.defaultStoredServer)
            )
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            #endif
            .accessibilityHint(AppSettings.storedServerError(settings.storedServer) ?? "")
            if let error = AppSettings.storedServerError(settings.storedServer) {
                StatusBanner(kind: .error, title: error)
            }
            if settings.storedServer != AppSettings.defaultStoredServer {
                Button("Reset to \(AppSettings.defaultStoredServer)") {
                    settings.storedServer = AppSettings.defaultStoredServer
                }
                .buttonVariant(.plain)
            }
        } header: {
            Text("Send as link")
        } footer: {
            Text(
                "Send as Link uploads encrypted files to this server. The link server holds them until the link expires and cannot read them; the key is in the link."
            )
        }

        Section {
            Picker("Connection", selection: $settings.transport) {
                Text("Automatic").tag(Transport.auto)
                Text("Relay Only").tag(Transport.relay)
            }
            .disabled(settings.onlyLocal)
            .accessibilityHint(settings.onlyLocal ? Self.connectionLockedReason : "")
        } header: {
            Text("Connection")
        } footer: {
            if settings.onlyLocal {
                Text(Self.connectionLockedReason)
            } else {
                Text(
                    "Automatic can carry files of 128 MiB or more directly between devices. Only the sender's choice applies; a receive follows it."
                )
            }
        }

        Section {
            Toggle("Local Network Only", isOn: $settings.onlyLocal)
            Toggle("Disable Compression", isOn: $settings.noCompress)
            Toggle("Zip Folders Before Sending", isOn: $settings.zipFolder)
        } header: {
            Text("Transfer")
        } footer: {
            Text("Local-only transfers never touch a relay on the internet.")
        }

        Section {
            TextField("Patterns, one per line", text: $settings.excludePatterns, axis: .vertical)
                .lineLimit(3...6)
                .autocorrectionDisabled()
            Toggle("Respect .gitignore", isOn: $settings.useGitIgnore)
        } header: {
            Text("Exclude from sends")
        }

        Section {
            Toggle("Confirm on Both Sides", isOn: $settings.bothSidesConfirm)
            Toggle("Auto-Accept Transfers", isOn: $settings.autoAccept)
            if settings.autoAccept {
                Picker("When a File Already Exists", selection: $settings.whenFileExists) {
                    Text("Keep Both").tag(FilePolicy.keepBoth)
                    Text("Replace").tag(FilePolicy.replace)
                }
            }
        } header: {
            Text("Confirmation")
        } footer: {
            if settings.autoAccept {
                // A Section footer is not a StatusBanner surface; Section
                // already styles footers as secondary, so a status color
                // here would tint body text (colors.md → Contrast, rule 2).
                Text(
                    "Files from anyone who has your code are saved without preview or confirmation. Keep Both saves a new copy next to an existing file; Replace overwrites it. Unsafe file names still cancel the transfer. Confirm on Both Sides overrides Auto-Accept Transfers."
                )
            } else {
                Text(
                    "Auto-Accept Transfers skips the file preview. Leave it off unless you fully trust the sender."
                )
            }
        }
    }
}
