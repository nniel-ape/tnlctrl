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
            Divider()
            actionsSection
        }
        .frame(width: 220)
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
                // Bring Settings window to front after menu bar panel dismisses
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // Find and focus the Settings window specifically
                    for window in NSApplication.shared.windows {
                        if window.title == "Settings" || window.identifier?.rawValue.contains("settings") == true {
                            window.makeKeyAndOrderFront(nil)
                            return
                        }
                    }
                    // Fallback: bring any visible window to front
                    NSApplication.shared.windows.first { $0.isVisible && $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
                }
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
