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

            RulesTab()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }

            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
        .frame(idealWidth: 700, idealHeight: 500)
        .background(WindowAccessor { window in
            // Register window with WindowManager for reliable tracking and activation
            window.styleMask.insert(.resizable)
            window.collectionBehavior.insert(.moveToActiveSpace)
            WindowManager.shared.registerSettingsWindow(window)
        })
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
            WindowManager.shared.unregisterSettingsWindow()
        }
    }
}

// MARK: - WindowAccessor

/// Helper view to access the underlying NSWindow from SwiftUI.
private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
