//
//  SettingsWindow.swift
//  TunnelMaster
//

import SwiftUI

struct SettingsWindow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            ServicesTab()
                .tabItem {
                    Label("Services", systemImage: "server.rack")
                }

            TunnelTab()
                .tabItem {
                    Label("Tunnel", systemImage: "arrow.triangle.branch")
                }

            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
        .frame(idealWidth: 700, idealHeight: 500)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
