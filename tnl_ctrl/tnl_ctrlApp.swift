//
//  tnl_ctrlApp.swift
//  tnl_ctrl
//
//  Created by Андрей on 13.01.2026.
//

import SwiftUI

@main
struct tnl_ctrlApp: App {
    @State private var appState = AppState()
    @State private var showOnboarding = OnboardingView.shouldShowOnboarding()

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

        Window("Welcome", id: "onboarding") {
            OnboardingView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    init() {
        // Show onboarding on first launch
        if OnboardingView.shouldShowOnboarding() {
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Welcome" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
