import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The Save Transfer History and Haptics rows, shared by the macOS Settings
/// scene and the iOS settings screen. Labels and footers are fixed by
/// design/content.md → Settings; a footer we write takes
/// `Color.textSecondary` (design/colors.md, rule 4).
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

        #if os(iOS)
        // iPhone only: iPad's haptics are inconsistent across models
        // (design/motion.md, "Haptics and sound").
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
