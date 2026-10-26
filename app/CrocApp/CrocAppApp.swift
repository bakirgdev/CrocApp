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
        #if os(macOS)
        _quickSend = State(initialValue: MenuBarQuickSend(controller: controller))
        #endif
        // AppRouter.shared is constructed before this init runs; attach the
        // controller now so AppRouter.isBusy can read isActive live.
        AppRouter.shared.attach(controller: controller)
    }

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
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
            // Without this every opened URL builds a new window and drops the
            // typed state of the old one.
            .handlesExternalEvents(preferring: [], allowing: ["*"])
            .frame(minWidth: 480, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 560, height: 700)
        #endif
        .commands {
            AppCommands(router: router, outputFolder: outputFolder, controller: controller)
            #if DIRECT
            UpdateCommands()
            #endif
        }

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
}
