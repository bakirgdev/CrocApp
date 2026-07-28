import SwiftUI

/// Power-option form sections (F13-F19), shared by the macOS Settings scene
/// and the iOS settings screen. Relay fields show croc defaults as prompts;
/// empty means "use default" (AppSettings.effective*).
struct PowerSettingsSections: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Section("Relay") {
            TextField(
                "Address", text: $settings.relayAddress,
                prompt: Text(AppSettings.defaultRelayAddress)
            )
            .autocorrectionDisabled()
            TextField(
                "IPv6 address", text: $settings.relayAddress6,
                prompt: Text(AppSettings.defaultRelayAddress6)
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
            Toggle("Local network only", isOn: $settings.onlyLocal)
            Toggle("Disable compression", isOn: $settings.noCompress)
            Toggle("Zip folders before sending", isOn: $settings.zipFolder)
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
            Toggle("Confirm on both sides", isOn: $settings.bothSidesConfirm)
            Toggle("Auto-accept incoming files", isOn: $settings.autoAccept)
        } header: {
            Text("Confirmation")
        } footer: {
            if settings.autoAccept {
                // A Section footer is not a StatusBanner surface; Section
                // already styles footers as secondary, so a status color
                // here would tint body text (colors.md rule 2 violation).
                Text(
                    "Files from anyone who has your code are saved without preview or confirmation. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept."
                )
            } else {
                Text(
                    "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."
                )
            }
        }
    }
}
