//
//  TunnelTab.swift
//  TunnelMaster
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

// MARK: - Preset Row

private struct PresetRow: View {
    let preset: TunnelPreset
    var isActive = false
    var serviceName: String?
    var chainHops = 0
    var enabledRuleCount = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .lineLimit(1)
                    .fontWeight(isActive ? .medium : .regular)
                    .foregroundStyle(isActive ? .primary : .secondary)

                if !summaryParts.isEmpty {
                    Text(summaryParts.joined(separator: " \u{00B7} "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            }

            Text(preset.mode.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(isActive ? .accentColor : .secondary)
        }
        .contentShape(Rectangle())
    }

    private var summaryParts: [String] {
        var parts: [String] = []
        if let name = serviceName {
            parts.append(name)
        }
        if chainHops >= 2 {
            parts.append("\(chainHops)-hop chain")
        }
        if enabledRuleCount > 0 {
            parts.append("\(enabledRuleCount) rule\(enabledRuleCount == 1 ? "" : "s")")
        }
        return parts
    }
}

// MARK: - Supporting Views

/// Chain editor with drag-to-reorder, add menu, and flow description
private struct ChainEditorView: View {
    let services: [Service]
    @Binding var tunnelConfig: TunnelConfig

    var body: some View {
        Group {
            if chainServices.isEmpty {
                HStack {
                    Image(systemName: "link.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No services in chain")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Chain list with drag-to-reorder
                List {
                    ForEach(Array(chainServices.enumerated()), id: \.element.id) { index, service in
                        ChainServiceRow(service: service, index: index + 1)
                    }
                    .onMove { from, to in
                        tunnelConfig.chain.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        tunnelConfig.chain.remove(atOffsets: offsets)
                    }
                }
                .frame(minHeight: 60, maxHeight: 150)
            }

            // Add to chain button
            if !availableForChain.isEmpty {
                Menu {
                    ForEach(availableForChain) { service in
                        Button {
                            tunnelConfig.chain.append(service.id)
                        } label: {
                            Label(service.name, systemImage: service.protocol.systemImage)
                        }
                    }
                } label: {
                    Label("Add to Chain", systemImage: "plus.circle")
                }
                .help("Add a service to the chain for multi-hop routing")
            }

            // Flow description
            if chainServices.count >= 2 {
                Text("Traffic routes: \(chainServices.map(\.name).joined(separator: " → "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Services currently in the chain
    private var chainServices: [Service] {
        tunnelConfig.chain.compactMap { chainId in
            services.first { $0.id == chainId }
        }
    }

    /// Services available to add to the chain
    private var availableForChain: [Service] {
        services.filter { service in
            !tunnelConfig.chain.contains(service.id)
        }
    }
}

private struct ChainServiceRow: View {
    let service: Service
    let index: Int

    var body: some View {
        HStack {
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Position number
            Text("\(index).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            // Protocol icon
            Image(systemName: service.protocol.systemImage)
                .foregroundStyle(.blue)

            // Service name
            Text(service.name)
                .lineLimit(1)

            Spacer()
        }
    }
}

/// Service picker with latency display and fallback selection logic
private struct ServicePickerView: View {
    let services: [Service]
    @Binding var tunnelConfig: TunnelConfig

    var body: some View {
        if services.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("No services available")
                    .foregroundStyle(.secondary)
            }
            Text("Add a service in the Services tab first.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Service", selection: serviceBinding()) {
                ForEach(services) { service in
                    Label {
                        HStack {
                            Text(service.name)
                            if let latency = service.latency {
                                Text("\(latency) ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: service.protocol.systemImage)
                    }
                    .tag(service.id)
                }
            }
        }
    }

    /// Creates a binding with fallback logic for missing services
    private func serviceBinding() -> Binding<UUID> {
        Binding(
            get: {
                // If no service selected, use first available
                if let selected = tunnelConfig.selectedServiceId,
                   services.contains(where: { $0.id == selected }) {
                    return selected
                }
                return services.first?.id ?? UUID()
            },
            set: { newValue in
                tunnelConfig.selectedServiceId = newValue
            }
        )
    }
}

/// Displays tunnel configuration validation results with color-coded severity indicators
private struct ValidationDisplayView: View {
    let result: TunnelConfigValidator.ValidationResult

    var body: some View {
        Section {
            if result.isValid, !result.hasWarnings {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configuration valid")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(result.issues) { issue in
                    HStack(alignment: .top) {
                        Image(systemName: issue.icon)
                            .foregroundStyle(issue.severity == .error ? .red : (issue.severity == .warning ? .orange : .blue))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.message)
                                .font(.callout)
                            if let suggestion = issue.suggestion {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Label("Status", systemImage: result.isValid ? "checkmark.shield" : "exclamationmark.shield")
        }
    }
}
