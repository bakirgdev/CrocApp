#if os(iOS)
import SwiftUI

/// The Settings tab; macOS uses the Settings scene (`SettingsView`) instead.
struct SettingsScreen: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.settingsPath) {
            Form {
                GeneralSettingsSections()
                SavedCodesSection()
                PowerSettingsSections()
                Section {
                    NavigationLink("Advanced", value: AppRouter.SettingsPage.advanced)
                } footer: {
                    Text("Proxies, sender IP, speed limit and more. The defaults suit most people.")
                }
                AboutSection()
            }
            .navigationTitle("Settings")
            .navigationDestination(for: AppRouter.SettingsPage.self) { _ in
                AdvancedSettingsView()
            }
        }
    }
}
#endif
