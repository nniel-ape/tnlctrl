//
//  MenuBarView.swift
//  TunnelMaster
//

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            Divider()
            actionsSection
        }
        .frame(width: 220)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(appState.isConnected ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(appState.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
            }

            if appState.isConnecting {
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleConnection()
            } label: {
                Label(
                    appState.isConnected ? "Disconnect" : "Connect",
                    systemImage: appState.isConnected ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()
                .padding(.vertical, 4)

            SettingsLink {
                Label("Settings...", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit TunnelMaster", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func toggleConnection() {
        if appState.isConnected {
            appState.isConnected = false
        } else {
            appState.isConnecting = true
            // Simulate connection delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appState.isConnecting = false
                appState.isConnected = true
            }
        }
    }
}
