//
//  CrocAppApp.swift
//  CrocApp
//
//  Created by admin on 21.07.2026.
//

import AppIntents
import CrocKit
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
        // croc spools small-file bundles in $TMPDIR, and a Mac app started from a
        // shell inherits one its sandbox denies. Once here, before any transfer:
        // changing it per transfer would race a getenv on another thread.
        CrocEngine.setTemporaryDirectory(FileManager.default.temporaryDirectory.path)
        let mode = LaunchMode.current
        let settings = mode.makeSettings()
        _settings = State(initialValue: settings)
        let history = HistoryStore(container: mode.makeHistoryContainer())
        _history = State(initialValue: history)
        let savedCodesStore = SavedCodes(secrets: mode.makeSecrets())
        _savedCodes = State(initialValue: savedCodesStore)
        let vault = StoredTransferVault(secrets: mode.makeSecrets())
        let controller = TransferController(settings: settings, vault: vault)
        controller.history = history
        controller.savedCodes = savedCodesStore
        _controller = State(initialValue: controller)
        let outputFolder = mode.makeOutputFolder()
        _outputFolder = State(initialValue: outputFolder)
        // Shortcuts actions can run right after launch, before any window.
        AppDependencyManager.shared.add(dependency: controller)
        AppDependencyManager.shared.add(dependency: outputFolder)
        // History for Shortcuts and Spotlight; only the app's history is the user's to index.
        HistoryEntityStore.install(
            for: history, settings: settings, index: mode.isLive ? SpotlightHistoryIndex() : nil)
        #if os(macOS)
        _quickSend = State(
            initialValue: MenuBarQuickSend(controller: controller, outputFolder: outputFolder))
        let relayHost = RelayHostController(settings: settings)
        _relayHost = State(initialValue: relayHost)
        // A secret typed just before quitting is still waiting for its Keychain
        // write (`AppSettings.flushSecrets`).
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { settings.flushSecrets() }
        }
        #endif
        let center = SystemNotificationCenter()
        let notifier = TransferNotifier(
            controller: controller, settings: settings, center: center,
            isAppActive: { SystemNotificationCenter.isAppActive },
            setDockBadge: Self.setDockBadge)
        _notifier = State(initialValue: notifier)
        let snapshotWriter = TransferSnapshotWriter(controller: controller, settings: settings)
        _snapshotWriter = State(initialValue: snapshotWriter)
        // These ask for permission, badge the Dock, write the user's widget data and
        // listen on the network, so only the real app starts them.
        if mode.isLive {
            #if os(macOS)
            // Only when the user's setting says so.
            relayHost.startAtLaunchIfWanted()
            #endif
            center.install()
            notifier.start()
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
            let icon = MenuBarIcon(phase: controller.phase, percent: controller.progressPercent)
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
            .environment(\.launchMode, LaunchMode.current)
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
