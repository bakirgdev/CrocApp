//
//  CrocAppApp.swift
//  CrocApp
//
//  Created by admin on 21.07.2026.
//

import AppIntents
import SwiftData
import SwiftUI

@main
struct CrocAppApp: App {
    @State private var settings: AppSettings
    @State private var controller: TransferController
    @State private var history: HistoryStore
    @State private var savedCodes: SavedCodes
    @State private var outputFolder: OutputFolderStore
    @State private var localNetwork = LocalNetworkChecker()
    @State private var router = AppRouter.shared
    @State private var notifier: TransferNotifier
    @State private var snapshotWriter: TransferSnapshotWriter

    static let mainWindowID = "main"

    #if os(macOS)
    @State private var quickSend: MenuBarQuickSend
    @State private var relayHost: RelayHostController
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        // Harness runs must not touch real settings, history or secrets: point
        // every store at memory.
        let harness = AutoVerify.isHarnessRun
        let settings =
            harness
            ? AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore())
            : AppSettings()
        _settings = State(initialValue: settings)
        let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: harness))
        _history = State(initialValue: history)
        let savedCodesStore = SavedCodes(secrets: harness ? MemorySecretStore() : KeychainStore())
        _savedCodes = State(initialValue: savedCodesStore)
        let vault = StoredTransferVault(secrets: harness ? MemorySecretStore() : KeychainStore())
        let controller = TransferController(settings: settings, vault: vault)
        controller.history = history
        controller.savedCodes = savedCodesStore
        _controller = State(initialValue: controller)
        let outputFolder = OutputFolderStore()
        _outputFolder = State(initialValue: outputFolder)
        // Shortcuts actions can run right after launch, before any window.
        AppDependencyManager.shared.add(dependency: controller)
        AppDependencyManager.shared.add(dependency: outputFolder)
        // History for Shortcuts and Spotlight; a harness run's history is not the user's.
        HistoryEntityStore.install(for: history, settings: settings, indexed: !harness)
        #if os(macOS)
        _quickSend = State(
            initialValue: MenuBarQuickSend(controller: controller, outputFolder: outputFolder))
        let relayHost = RelayHostController(settings: settings)
        _relayHost = State(initialValue: relayHost)
        // The relay listens on the network, so it starts only when the user's
        // setting says so, never in a harness run.
        if !harness { relayHost.startAtLaunchIfWanted() }
        #endif
        let center = SystemNotificationCenter()
        let notifier = TransferNotifier(
            controller: controller, settings: settings, center: center,
            isAppActive: { SystemNotificationCenter.isAppActive },
            setDockBadge: Self.setDockBadge)
        _notifier = State(initialValue: notifier)
        // A harness run must not ask for permission or badge the Dock.
        if !harness {
            center.install()
            notifier.start()
        }
        let snapshotWriter = TransferSnapshotWriter(controller: controller, settings: settings)
        _snapshotWriter = State(initialValue: snapshotWriter)
        // A harness run must not write the user's widget data.
        if !harness {
            snapshotWriter.start()
            history.observers.append(snapshotWriter)
        }
        // Widget buttons and the Control Center control land here.
        OpenScreen.handler = { target in
            switch target {
            case .send: AppRouter.shared.path = [.send]
            case .receive: AppRouter.shared.openReceive()
            }
            #if os(macOS)
            AppRouter.shared.showMainWindow()
            #endif
        }
        // AppRouter.shared is constructed before this init runs; attach the
        // controller now so AppRouter.isBusy can read isActive live.
        AppRouter.shared.attach(controller: controller)
    }

    private static func setDockBadge(_ badge: String?) {
        #if os(macOS)
        NSApp.dockTile.badgeLabel = badge
        #endif
    }

    var body: some Scene {
        mainScene

        #if os(macOS)
        MenuBarExtra(
            isInserted: Binding(
                get: { settings.showInMenuBar }, set: { settings.showInMenuBar = $0 })
        ) {
            MenuBarQuickSendView(quickSend: quickSend)
                .environment(controller)
                .environment(relayHost)
        } label: {
            let icon = MenuBarIcon(phase: controller.phase, progress: controller.progress)
            HStack(spacing: Spacing.space1) {
                Image(systemName: icon.symbol)
                if let percent = icon.percent { Text(verbatim: "\(percent)%").monospacedDigit() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(icon.label)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(outputFolder)
                .environment(settings)
                .environment(savedCodes)
                .environment(relayHost)
                .environment(localNetwork)
        }
        // A Settings scene's default .automatic resizability resolves to
        // .contentSize — min == max == content size — which is where the old
        // fixed 480x450 came from. It was never a platform limit.
        // .defaultSize is needed alongside it: with only a minimum declared,
        // AppKit picked its own opening width (measured at ~900) and left the
        // form marooned in the middle.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 780)
        #endif
    }

    /// One transfer runs at a time, so the app has one main window and one
    /// navigation path. macOS takes the single-instance `Window`; iOS has no
    /// `Window` scene, so iPad stays a `WindowGroup` limited to one scene by
    /// `UIApplicationSupportsMultipleScenes = NO` in `Config/CrocApp-Info.plist`.
    @SceneBuilder private var mainScene: some Scene {
        #if os(macOS)
        Window("CrocApp", id: Self.mainWindowID) { mainContent }
            .defaultSize(width: 880, height: 700)
            .commands { appCommands }
        #else
        WindowGroup(id: Self.mainWindowID) { mainContent }
            .commands { appCommands }
        #endif
    }

    private var mainContent: some View {
        ContentView()
            .environment(controller)
            .environment(settings)
            .environment(outputFolder)
            .environment(localNetwork)
            .environment(router)
            .environment(history)
            .environment(savedCodes)
            .modelContainer(history.container)
            #if os(macOS)
        .modifier(CaptureWindowOpener(router: router))
            #endif
            .onOpenURL { url in
                if let link = TransferLink.parse(url.absoluteString) { router.open(link) }
            }
            #if os(macOS)
        .frame(minWidth: 720, minHeight: 560)
        #endif
    }

    @CommandsBuilder private var appCommands: some Commands {
        AppCommands(router: router, outputFolder: outputFolder, controller: controller)
        #if DIRECT
        UpdateCommands()
        #endif
    }
}

#if os(macOS)
/// Hands the router the `openWindow` action, so a notification tap or a widget
/// button can reopen the main window after it was closed (`AppRouter.showMainWindow`).
private struct CaptureWindowOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let router: AppRouter

    func body(content: Content) -> some View {
        content.onAppear {
            router.windowOpener = { openWindow(id: CrocAppApp.mainWindowID) }
        }
    }
}
#endif
