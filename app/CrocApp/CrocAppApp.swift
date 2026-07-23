//
//  CrocAppApp.swift
//  CrocApp
//
//  Created by admin on 21.07.2026.
//

import SwiftUI

@main
struct CrocAppApp: App {
    @State private var settings: AppSettings
    @State private var controller: TransferController
    @State private var outputFolder = OutputFolderStore()
    @State private var localNetwork = LocalNetworkChecker()
    @State private var router = AppRouter.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _controller = State(initialValue: TransferController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(controller)
                .environment(settings)
                .environment(outputFolder)
                .environment(localNetwork)
                .environment(router)
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
