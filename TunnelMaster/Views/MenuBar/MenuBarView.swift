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
            servicesSection
            Divider()
            actionsSection
        }
        .frame(width: 240)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: appState.tunnelStatus.systemImage)
                    .foregroundStyle(statusColor)
                Text(appState.tunnelStatus.displayName)
                    .font(.headline)

                if appState.isTransitioning {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            if let error = appState.tunnelError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if appState.helperInstaller.status != .installed {
                Text("Helper not installed")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch appState.tunnelStatus {
        case .running: .green
        case .connecting, .disconnecting: .orange
        case .error: .red
        case .stopped: .secondary
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.enabledServices.isEmpty {
                Text("No services configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                ForEach(appState.enabledServices.prefix(5)) { service in
                    HStack {
                        Image(systemName: service.protocol.systemImage)
                            .frame(width: 16)
                        Text(service.name)
                            .lineLimit(1)
                        Spacer()
                        if let latency = service.latency {
                            Text("\(latency)ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }

                if appState.enabledServices.count > 5 {
                    Text("+\(appState.enabledServices.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task {
                    await appState.toggleConnection()
                }
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
            .disabled(appState.isTransitioning || appState.helperInstaller.status != .installed)

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
}
