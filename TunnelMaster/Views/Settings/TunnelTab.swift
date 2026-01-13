//
//  TunnelTab.swift
//  TunnelMaster
//

import SwiftUI

struct TunnelTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Tunnel Mode") {
                Picker("Mode", selection: $state.tunnelConfig.mode) {
                    ForEach(TunnelMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(appState.tunnelConfig.mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.tunnelConfig.mode == .split {
                Section("Routing Rules") {
                    if appState.tunnelConfig.rules.isEmpty {
                        Text("No rules configured. All traffic will go direct.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.tunnelConfig.rules) { rule in
                            HStack {
                                Text(rule.type.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.secondary.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(rule.value)

                                Spacer()

                                Image(systemName: rule.outbound.systemImage)
                                Text(rule.outbound.displayName)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Add Rule...") {
                        // TODO: Task 17 - Rules editor
                    }
                }
            }

            Section("Proxy Chain") {
                if appState.tunnelConfig.chain.isEmpty {
                    Text("No chain configured. Traffic will use a single proxy.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appState.tunnelConfig.chain.enumerated()), id: \.element) { index, serviceId in
                        if let service = appState.services.first(where: { $0.id == serviceId }) {
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                Image(systemName: service.protocol.systemImage)
                                Text(service.name)
                            }
                        }
                    }
                }

                Text("Coming soon: drag-and-drop chain editor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.tunnelConfig) {
            appState.saveTunnelConfig()
        }
    }
}
