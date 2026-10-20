import SwiftUI

/// Two-verb home (prior-art pattern): giant Send / Receive, nothing else.
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(TransferController.self) private var controller

    // The two verbs are the page's whole job, so they are tall: 100 is a
    // component constant (it is not a control size).
    private static let verbMinHeight: CGFloat = 100

    private var hasPendingRequest: Bool {
        if case .incoming = controller.phase { return true }
        return false
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            VStack(spacing: Spacing.space6) {
                TrustBadge(relay: settings.relayKind)

                if hasPendingRequest {
                    // components.md → AcceptGate: a live request is never lost.
                    // Backing out of the transfer screen answers nothing, so the
                    // way back stays on Home until the sender gives up or the
                    // user answers.
                    StatusBanner(
                        kind: .info,
                        title: "Files are waiting for your answer",
                        detail: "The other device is waiting for you to accept or decline.",
                        actionTitle: "Review"
                    ) {
                        router.path = [.receive]
                    }
                }

                Button {
                    router.path.append(.send)
                } label: {
                    Label("Send", systemImage: "arrow.up.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: Self.verbMinHeight)
                }
                .buttonVariant(.prominent)
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
                            .background(Color.accentSolid, in: Capsule())
                            .offset(x: Spacing.space3, y: -Spacing.space3)
                            .accessibilityLabel(
                                "^[\(router.pendingSendURLs.count) file](inflect: true) waiting to send"
                            )
                    }
                }

                Button {
                    router.path.append(.receive)
                } label: {
                    Label("Receive", systemImage: "arrow.down.circle.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: Self.verbMinHeight)
                }
                .buttonVariant(.secondary)
            }
            .padding(Spacing.space5)
            .frame(maxWidth: LayoutCap.contentMaxWidth)
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
                case .advancedSettings: AdvancedSettingsView()
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
            Section {
                NavigationLink("Advanced", value: AppRouter.Route.advancedSettings)
            } footer: {
                Text("Proxies, ports, encryption curve and more. The defaults suit most people.")
            }
            AboutSection()
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    HomeView()
        .environment(AppRouter.shared)
        .environment(AppSettings())
        .environment(
            TransferController(
                settings: AppSettings(), vault: StoredTransferVault(secrets: MemorySecretStore())))
}
