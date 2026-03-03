//
//  TunnelTab.swift
//  tnl_ctrl
//

import SwiftUI

struct TunnelTab: View {
    @Environment(AppState.self) private var appState

    @State private var validationResult: TunnelConfigValidator.ValidationResult = .valid
    @State private var showSavePopover = false
    @State private var newPresetName = ""
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var presetToRename: TunnelPreset?

    private var sortedPresets: [TunnelPreset] {
        appState.presets.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        @Bindable var state = appState

        Form {
            // MARK: Presets

            Section {
                if appState.presets.isEmpty {
                    Text("Save your current tunnel configuration as a preset.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPresets) { preset in
                        PresetRow(
                            preset: preset,
                            isActive: preset.id == appState.activePresetId,
                            serviceName: resolveServiceName(for: preset),
                            chainHops: preset.chainEnabled ? preset.chain.count : 0,
                            enabledRuleCount: preset.enabledRuleIds.count
                        )
                        .onTapGesture(count: 2) {
                            appState.loadPreset(preset)
                        }
                        .contextMenu {
                            Button {
                                appState.loadPreset(preset)
                            } label: {
                                Label("Load", systemImage: "tray.and.arrow.down")
                            }

                            Button {
                                appState.updatePreset(id: preset.id)
                            } label: {
                                Label("Update with Current Config", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Button {
                                presetToRename = preset
                                renameText = preset.name
                                showRenameAlert = true
                            } label: {
                                Label("Rename\u{2026}", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive) {
                                appState.deletePreset(id: preset.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    newPresetName = ""
                    showSavePopover = true
                } label: {
                    Label("Save Current Config\u{2026}", systemImage: "plus.circle")
                }
                .popover(isPresented: $showSavePopover, arrowEdge: .trailing) {
                    VStack(spacing: 12) {
                        Text("Save Preset")
                            .font(.headline)

                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                            .onSubmit {
                                savePresetFromPopover()
                            }

                        HStack {
                            Button("Cancel") {
                                showSavePopover = false
                            }
                            .keyboardShortcut(.cancelAction)

                            Spacer()

                            Button("Save") {
                                savePresetFromPopover()
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding()
                }
            } header: {
                Label("Presets", systemImage: "star")
            }

            // MARK: Tunnel Mode

            Section {
                Picker("Mode", selection: $state.tunnelConfig.mode) {
                    ForEach(TunnelMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .help("Choose between routing all traffic or only matching rules through the proxy")

                Text(appState.tunnelConfig.mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Tunnel Mode", systemImage: "network")
            }

            // MARK: Outbound Service

            Section {
                ServicePickerView(services: appState.services, tunnelConfig: $state.tunnelConfig)
                    .help("Select the primary proxy service to route traffic through")

                Toggle("Enable chaining (multi-hop)", isOn: $state.tunnelConfig.chainEnabled)
                    .disabled(appState.services.count < 2)
                    .help("Route traffic through multiple proxies in sequence for enhanced privacy")

                if appState.tunnelConfig.chainEnabled {
                    ChainEditorView(services: appState.services, tunnelConfig: $state.tunnelConfig)
                }
            } header: {
                Label("Outbound Service", systemImage: "arrow.up.forward.app")
            }

            // MARK: Validation

            ValidationDisplayView(result: validationResult)
        }
        .formStyle(.grouped)
        .onChange(of: appState.tunnelConfig) { _, newValue in
            appState.scheduleTunnelConfigSave()
            validationResult = TunnelConfigValidator.validate(config: newValue, services: appState.services)
        }
        .onChange(of: appState.services) { _, _ in
            validationResult = TunnelConfigValidator.validate(config: appState.tunnelConfig, services: appState.services)
        }
        .task {
            validationResult = TunnelConfigValidator.validate(config: appState.tunnelConfig, services: appState.services)
        }
        .alert("Rename Preset", isPresented: $showRenameAlert) {
            TextField("New name", text: $renameText)
            Button("Rename") {
                if let preset = presetToRename {
                    appState.renamePreset(id: preset.id, newName: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private func resolveServiceName(for preset: TunnelPreset) -> String? {
        guard let serviceId = preset.selectedServiceId else { return nil }
        return appState.services.first { $0.id == serviceId }?.name
    }

    private func savePresetFromPopover() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.saveCurrentConfigAsPreset(name: trimmed)
        showSavePopover = false
    }
}
