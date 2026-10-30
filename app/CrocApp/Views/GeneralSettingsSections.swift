import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The Save Transfer History, Show History in Spotlight, Notifications and Haptics rows, shared by the macOS Settings
/// scene and the iOS settings screen. Labels and footers are fixed by
/// docs/knowledge/app-ui-architecture.md → Settings copy; a footer we write takes
/// `Color.textSecondary` (design/principles.md, Contrast).
struct GeneralSettingsSections: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Section {
            Toggle("Save Transfer History", isOn: $settings.saveTransferHistory)
        } footer: {
            Text("Finished transfers are listed in History, which stays on this device.")
                .foregroundStyle(Color.textSecondary)
        }

        Section {
            Toggle("Show History in Spotlight", isOn: $settings.indexHistoryInSpotlight)
                .disabled(!settings.saveTransferHistory)
        } footer: {
            Text("Spotlight on this device can find past transfers by their file names.")
                .foregroundStyle(Color.textSecondary)
        }

        Section {
            Toggle("Notifications", isOn: $settings.notificationsEnabled)
            Toggle("Show File Names in Notifications", isOn: $settings.notificationsShowFileNames)
                .disabled(!settings.notificationsEnabled)
        } footer: {
            Text(
                "When CrocApp is in the background, a transfer that finishes, fails or needs your answer sends a notification. It never shows a code phrase or link, and shows file names only if you turn that on. CrocApp asks the system for permission when you start your first transfer."
            )
            .foregroundStyle(Color.textSecondary)
        }

        #if os(iOS)
        // iPhone only: iPad's haptics are inconsistent across models
        // (design/principles.md, "Haptics").
        if UIDevice.current.userInterfaceIdiom == .phone {
            Section {
                Toggle("Haptics", isOn: $settings.haptics)
            } footer: {
                Text(
                    "A short tap when you copy or scan a code, and when a transfer finishes, fails or needs your answer."
                )
                .foregroundStyle(Color.textSecondary)
            }
        }
        #endif
    }
}

#Preview {
    Form { GeneralSettingsSections() }
        .formStyle(.grouped)
        .environment(AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore()))
}
