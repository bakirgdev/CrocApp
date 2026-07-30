import SwiftUI

/// Two-verb home (prior-art pattern): giant Send / Receive, nothing else.
struct HomeView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            VStack(spacing: 20) {
                NavigationLink(value: AppRouter.Route.send) {
                    Label("Send", systemImage: "arrow.up.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.borderedProminent)
                .overlay(alignment: .topTrailing) {
                    // Dock/window/share drops queue into pendingSendURLs
                    // without navigating while a transfer is active (queue-
                    // while-busy policy) -- surface the count so it isn't
                    // discoverable only by manually visiting Send.
                    if !router.pendingSendURLs.isEmpty {
                        Text("\(router.pendingSendURLs.count)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.onAccent)
                            .padding(.horizontal, Spacing.space3)
                            .padding(.vertical, Spacing.space1)
                            .background(Color.accentFill, in: Capsule())
                            .offset(x: Spacing.space3, y: -Spacing.space3)
                            .accessibilityLabel(
                                "^[\(router.pendingSendURLs.count) file](inflect: true) waiting to send"
                            )
                    }
                }

                NavigationLink(value: AppRouter.Route.receive) {
                    Label("Receive", systemImage: "arrow.down.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 480)
            .navigationTitle("CrocApp")
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: AppRouter.Route.history) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Transfer history")
                    NavigationLink(value: AppRouter.Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: AppRouter.Route.howItWorks) {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("How croc keeps transfers private")
                }
                #else
                ToolbarItem {
                    NavigationLink(value: AppRouter.Route.howItWorks) {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("How croc keeps transfers private")
                }
                ToolbarItem {
                    NavigationLink(value: AppRouter.Route.history) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Transfer history")
                }
                #endif
            }
            .navigationDestination(for: AppRouter.Route.self) { route in
                switch route {
                case .send: SendView()
                case .receive: ReceiveView()
                case .settings: SettingsScreen()
                case .howItWorks: HowItWorksView()
                case .history: HistoryView()
                }
            }
        }
    }
}

/// iOS settings screen; macOS uses the Settings scene instead.
struct SettingsScreen: View {
    var body: some View {
        Form {
            PowerSettingsSections()
        }
        .navigationTitle("Settings")
    }
}

#Preview { HomeView().environment(AppRouter.shared) }
