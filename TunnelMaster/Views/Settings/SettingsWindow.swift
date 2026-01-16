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
                    Label("Services", systemImage: "point.3.connected.trianglepath.dotted")
                }

            ServersTab()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
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
            NSApplication.shared.setActivationPolicy(.regular)
            // Delay to let the window fully initialize before activating
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                // Find and focus the Settings window
                for window in NSApplication.shared.windows where window.isVisible && window.canBecomeKey {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
