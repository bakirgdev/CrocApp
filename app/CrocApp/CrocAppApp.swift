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
    @State private var outputFolder: OutputFolderStore
    @State private var localNetwork = LocalNetworkChecker()
    @State private var router = AppRouter.shared

    static let mainWindowID = "main"

    #if os(macOS)
    @State private var quickSend: MenuBarQuickSend
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
        let vault = StoredTransferVault(secrets: harness ? MemorySecretStore() : KeychainStore())
        let controller = TransferController(settings: settings, vault: vault)
        controller.history = history
        _controller = State(initialValue: controller)
        let outputFolder = OutputFolderStore()
        _outputFolder = State(initialValue: outputFolder)
        // Shortcuts actions can run right after launch, before any window.
        AppDependencyManager.shared.add(dependency: controller)
        AppDependencyManager.shared.add(dependency: outputFolder)
        // History for Shortcuts and Spotlight; a harness run's history is not the user's.
        HistoryEntityStore.install(for: history, settings: settings, indexed: !harness)
        #if os(macOS)
        _quickSend = State(initialValue: MenuBarQuickSend(controller: controller))
        #endif
        // AppRouter.shared is constructed before this init runs; attach the
        // controller now so AppRouter.isBusy can read isActive live.
        AppRouter.shared.attach(controller: controller)
    }

    var body: some Scene {
        mainScene

        #if os(macOS)
        MenuBarExtra(
            "CrocApp", systemImage: "arrow.up.arrow.down.circle",
            isInserted: Binding(
                get: { settings.showInMenuBar }, set: { settings.showInMenuBar = $0 })
        ) {
            MenuBarQuickSendView(quickSend: quickSend)
                .environment(controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(outputFolder)
                .environment(settings)
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
            .defaultSize(width: 560, height: 700)
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
            .modelContainer(history.container)
            .onOpenURL { url in
                if let link = TransferLink.parse(url.absoluteString) { router.open(link) }
            }
            #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
            #endif
    }

    @CommandsBuilder private var appCommands: some Commands {
        AppCommands(router: router, outputFolder: outputFolder, controller: controller)
        #if DIRECT
        UpdateCommands()
        #endif
    }
}
