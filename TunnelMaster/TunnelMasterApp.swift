//
//  TunnelMasterApp.swift
//  TunnelMaster
//
//  Created by Андрей on 13.01.2026.
//

import SwiftUI

@main
struct TunnelMasterApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .task {
                    await appState.load()
                }
        } label: {
            Image(systemName: appState.isConnected ? "network" : "network.slash")
        }

        Settings {
            SettingsWindow()
                .environment(appState)
        }
    }
}
