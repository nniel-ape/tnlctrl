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

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.enabledServices.isEmpty {
                Button {} label: {
                    Text("No services configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(true)
            } else {
                ForEach(appState.enabledServices.prefix(5)) { service in
                    Button {} label: {
                        HStack(spacing: 8) {
                            Image(systemName: service.protocol.systemImage)
                                .foregroundStyle(.secondary)
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
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
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

            SettingsLink {
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
            }
            .buttonStyle(MenuButtonStyle())

            MenuButton(title: "Quit TunnelMaster", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct MenuButton: View {
    let title: String
    let systemImage: String
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

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
            .background(isHovered && !disabled ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .onHover { isHovered = $0 }
    }
}

private struct MenuButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            .onHover { isHovered = $0 }
    }
}
