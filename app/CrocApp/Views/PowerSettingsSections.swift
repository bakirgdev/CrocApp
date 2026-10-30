import CrocKit
import SwiftUI

/// Power-option form sections, shared by the macOS Settings scene
/// and the iOS settings screen. Empty relay fields mean croc's defaults: with
/// no custom relay, the public relay pool.
struct PowerSettingsSections: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Section("Relay") {
            TextField(
                "Address", text: $settings.relayAddress,
                prompt: Text("Public relay pool")
            )
            .urlEntry()
            TextField(
                "IPv6 Address", text: $settings.relayAddress6,
                prompt: Text("Public relay pool")
            )
            .urlEntry()
            SecureField(
                "Password", text: $settings.relayPassword,
                prompt: Text("Default")
            )
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
            if settings.unsavedSecrets.contains(.relayPassword) {
                StatusBanner(
                    kind: .error, title: AppSettings.secretNotSavedTitle,
                    detail: AppSettings.secretNotSavedDetail)
            }
        }

        Section {
            TextField(
                "Link Server", text: $settings.storedServer,
                prompt: Text(AppSettings.defaultStoredServer)
            )
            .urlEntry()
            .accessibilityHint(AppSettings.storedServerError(settings.storedServer) ?? "")
            if let error = AppSettings.storedServerError(settings.storedServer) {
                StatusBanner(kind: .error, title: error)
            }
            if settings.storedServer != AppSettings.defaultStoredServer {
                Button {
                    settings.storedServer = AppSettings.defaultStoredServer
                } label: {
                    Text("Reset to \(AppSettings.defaultStoredServer)").hitTarget()
                }
                .buttonVariant(.plain)
            }
        } header: {
            Text("Send as link")
        } footer: {
            Text(
                "Send as Link uploads files, encrypted on your device, to this server. It cannot read them, because the key is in the link."
            )
            .foregroundStyle(Color.textSecondary)
        }

        Section {
            Toggle("Local Network Only", isOn: $settings.onlyLocal)
            Toggle("Disable Compression", isOn: $settings.noCompress)
            Toggle("Zip Folders Before Sending", isOn: $settings.zipFolder)
        } header: {
            Text("Transfer")
        } footer: {
            Text("Local-only transfers never touch a relay on the internet.")
                .foregroundStyle(Color.textSecondary)
        }

        Section {
            TextField("Patterns, one per line", text: $settings.excludePatterns, axis: .vertical)
                .lineLimit(3...6)
                .autocorrectionDisabled()
                #if os(iOS)
            .textInputAutocapitalization(.never)
                #endif
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
            // A Section footer is not a StatusBanner surface, so a status
            // color here would tint body text (principles.md → Contrast, rule 2).
            if settings.autoAccept {
                Text(
                    "Files from anyone who has your code are saved without a preview, unless Confirm on Both Sides is on. Replace overwrites existing files, and unsafe file names still cancel the transfer."
                )
                .foregroundStyle(Color.textSecondary)
            } else {
                Text(
                    "Auto-Accept Transfers saves files without a preview, so leave it off unless you fully trust the sender."
                )
                .foregroundStyle(Color.textSecondary)
            }
        }
    }
}
