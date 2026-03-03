//
//  MenuBarView.swift
//  TunnelMaster
//

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            if appState.pendingConfigReload, appState.isConnected {
                reloadBanner
            }
            Divider()
            actionsSection
        }
        .frame(width: 220)
        .onChange(of: appState.isConnected) { _, connected in
            if !connected {
                appState.pendingConfigReload = false
            }
        }
    }

    private var reloadBanner: some View {
        Button {
            Task {
                do {
                    try await appState.tunnelManager.reload(
                        services: appState.services,
                        tunnelConfig: appState.tunnelConfig,
                        appSettings: appState.settings
                    )
                    appState.pendingConfigReload = false
                } catch {
                    // Reload failed — banner stays visible
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .frame(width: 16)
                Text("Config changed — Reload")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusSection: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: appState.tunnelStatus.systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 16)
                Text(appState.tunnelStatus.displayName)
                    .font(.headline)
                Spacer()
                if appState.isTransitioning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(true)
    }

    private var statusColor: Color {
        switch appState.tunnelStatus {
        case .running: .green
        case .connecting, .disconnecting: .orange
        case .error: .red
        case .stopped: .secondary
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuButton(
                title: appState.isConnected ? "Disconnect" : "Connect",
                systemImage: appState.isConnected ? "stop.fill" : "play.fill",
                disabled: appState.isTransitioning || appState.helperInstaller.status != .installed
            ) {
                Task {
                    await appState.toggleConnection()
                }
            }

            Divider()

            Button {
                openSettings()
                WindowManager.shared.activateSettings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .frame(width: 16)
                    Text("Settings...")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            MenuButton(title: "Quit TunnelMaster", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}
