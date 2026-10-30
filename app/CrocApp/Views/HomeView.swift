import SwiftData
import SwiftUI

/// The compact root (design/components.md → Home): the trust badge, a banner
/// while a request waits, the giant Send and Receive, then the recent
/// transfers. The page is a `Form`, so the recent transfers are a system
/// grouped section and the page scrolls when the text is large.
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(TransferController.self) private var controller
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// components.md → Home: Send and Receive are 100 tall at least. A
    /// component constant, not a control size.
    private static let actionMinHeight: CGFloat = 100

    private var hasPendingRequest: Bool {
        if case .incoming = controller.phase { return true }
        return false
    }

    /// principles.md → Motion: the banner fades in while travelling
    /// down into place, and leaves with opacity alone. Instant under Reduce
    /// Motion.
    private var bannerTransition: AnyTransition {
        reduceMotion
            ? .identity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -Spacing.space3))
                    .animation(Motion.easeOut(Motion.durationBase)),
                removal: .opacity.animation(Motion.easeStandard(Motion.durationFast)))
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Form {
                Section {
                    actions
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

                RecentTransfersSection()
            }
            .formStyle(.grouped)
            .frame(maxWidth: LayoutCap.contentMaxWidth)
            .navigationTitle("CrocApp")
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: AppRouter.Route.history) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Transfer history")
                    .help("History")
                    NavigationLink(value: AppRouter.Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .help("Settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: AppRouter.Route.howItWorks) {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("How croc keeps transfers private")
                    .help("How It Works")
                }
                #else
                ToolbarItem {
                    NavigationLink(value: AppRouter.Route.howItWorks) {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("How croc keeps transfers private")
                    .help("How It Works")
                }
                ToolbarItem {
                    NavigationLink(value: AppRouter.Route.history) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Transfer history")
                    .help("History")
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

    /// The first three blocks, in the book's order, in one row. The animation
    /// sits on the container so the actions slide when the banner takes its
    /// slot instead of jumping.
    private var actions: some View {
        VStack(spacing: Spacing.space6) {
            TrustBadge(relay: settings.relayKind)

            if hasPendingRequest {
                // components.md → AcceptGate: a live request is never lost.
                // Backing out of the transfer screen answers nothing, so the
                // way back stays on Home until the sender gives up or the
                // user answers.
                StatusBanner(
                    kind: .info,
                    title: String(localized: "Files are waiting for your answer"),
                    detail: String(
                        localized: "The other device is waiting for you to accept or decline."),
                    actionTitle: "Review"
                ) {
                    router.path = [.receive]
                }
                .transition(bannerTransition)
            }

            Button {
                router.path.append(.send)
            } label: {
                Label("Send", systemImage: "arrow.up.circle.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: Self.actionMinHeight)
            }
            .buttonVariant(.prominent)
            .overlay(alignment: .topTrailing) {
                // Dock/window/share drops queue into pendingSendURLs
                // without navigating while a transfer is active (queue-
                // while-busy policy) -- surface the count so it isn't
                // discoverable only by manually visiting Send.
                if !router.pendingSendURLs.isEmpty {
                    Text(router.pendingSendURLs.count, format: .number)
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
                    .frame(maxWidth: .infinity, minHeight: Self.actionMinHeight)
            }
            .buttonVariant(.secondary)
        }
        .padding(.vertical, Spacing.space3)
        .animation(
            reduceMotion ? nil : Motion.easeOut(Motion.durationBase), value: hasPendingRequest)
    }
}

/// iOS settings screen; macOS uses the Settings scene instead.
struct SettingsScreen: View {
    var body: some View {
        Form {
            GeneralSettingsSections()
            PowerSettingsSections()
            Section {
                NavigationLink("Advanced", value: AppRouter.Route.advancedSettings)
            } footer: {
                Text("Proxies, sender IP, speed limit and more. The defaults suit most people.")
            }
            AboutSection()
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
    return HomeView()
        .environment(AppRouter.shared)
        .environment(AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore()))
        .environment(
            TransferController(
                settings: AppSettings(), vault: StoredTransferVault(secrets: MemorySecretStore()))
        )
        .environment(history)
        .modelContainer(history.container)
}
