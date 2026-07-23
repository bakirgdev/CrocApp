//
//  CrocAppApp.swift
//  CrocApp
//
//  Created by admin on 21.07.2026.
//

import SwiftUI

@main
struct CrocAppApp: App {
    @State private var controller = TransferController()
    @State private var outputFolder = OutputFolderStore()
    @State private var localNetwork = LocalNetworkChecker()
    @State private var router = AppRouter.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(controller)
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

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(outputFolder)
        }
        #endif
    }
}
