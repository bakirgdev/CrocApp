//
//  CrocAppApp.swift
//  CrocApp
//
//  Created by admin on 21.07.2026.
//

import SwiftData
import SwiftUI

@main
struct CrocAppApp: App {
    @State private var settings: AppSettings
    @State private var controller: TransferController
    @State private var history: HistoryStore
    @State private var outputFolder = OutputFolderStore()
    @State private var localNetwork = LocalNetworkChecker()
    @State private var router = AppRouter.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        // Harness transfers must not pollute real history (mirrors the
        // settings persist=false channel) -- point the store at memory.
        let harness = AutoVerify.isHarnessRun
        let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: harness))
        _history = State(initialValue: history)
        let controller = TransferController(settings: settings)
        controller.history = history
        _controller = State(initialValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(controller)
                .environment(settings)
                .environment(outputFolder)
                .environment(localNetwork)
                .environment(router)
                .environment(history)
                .modelContainer(history.container)
                #if os(macOS)
            .frame(minWidth: 480, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 560, height: 700)
        #endif
        .commands {
            AppCommands(router: router, outputFolder: outputFolder, controller: controller)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(outputFolder)
                .environment(settings)
        }
        #endif
    }
}
