//
//  TunnelTab.swift
//  TunnelMaster
//

import SwiftUI

struct TunnelTab: View {
    @Environment(AppState.self) private var appState

    // MARK: - Sheet Presentation

    enum SheetDestination: Identifiable {
        case presetManager

        var id: String {
            switch self {
            case .presetManager: "presetManager"
            }
        }
    }

    @State private var activeSheet: SheetDestination?
    @State private var validationResult: TunnelConfigValidator.ValidationResult = .valid

    var body: some View {
        @Bindable var state = appState

        Form {
            tunnelModeSection
            outboundServiceSection
            if appState.tunnelConfig.mode == .split {
                routingRulesSection
            }
            validationSection
        }
        .formStyle(.grouped)
        .onChange(of: appState.tunnelConfig) { _, newValue in
            appState.saveTunnelConfig()
            validationResult = TunnelConfigValidator.validate(config: newValue, services: appState.services)
        }
        .onChange(of: appState.services) { _, _ in
            validationResult = TunnelConfigValidator.validate(config: appState.tunnelConfig, services: appState.services)
        }
        .task {
            validationResult = TunnelConfigValidator.validate(config: appState.tunnelConfig, services: appState.services)
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .presetManager:
                PresetManagerSheet()
            }
        }
    }

    // MARK: - Tunnel Mode Section

    private var tunnelModeSection: some View {
        @Bindable var state = appState

        return Section {
            Picker("Mode", selection: $state.tunnelConfig.mode) {
                ForEach(TunnelMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            Text(appState.tunnelConfig.mode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Label("Tunnel Mode", systemImage: "network")
        }
    }

    // MARK: - Outbound Service Section

    private var outboundServiceSection: some View {
        @Bindable var state = appState

        return Section {
            // Service picker
            if appState.services.isEmpty {
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
                Picker("Service", selection: Binding(
                    get: {
                        // If no service selected, use first available
                        if let selected = state.tunnelConfig.selectedServiceId,
                           appState.services.contains(where: { $0.id == selected }) {
                            return selected
                        }
                        return appState.services.first?.id ?? UUID()
                    },
                    set: { newValue in
                        state.tunnelConfig.selectedServiceId = newValue
                    }
                )) {
                    ForEach(appState.services) { service in
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

            // Chain toggle
            Toggle("Enable chaining (multi-hop)", isOn: $state.tunnelConfig.chainEnabled)
                .disabled(appState.services.count < 2)

            // Chain editor
            if appState.tunnelConfig.chainEnabled {
                chainEditor
            }
        } header: {
            Label("Outbound Service", systemImage: "arrow.up.forward.app")
        }
    }

    private var chainEditor: some View {
        @Bindable var state = appState
        let chainServices = appState.tunnelConfig.chain.compactMap { chainId in
            appState.services.first { $0.id == chainId }
        }

        return Group {
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
                        state.tunnelConfig.chain.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        state.tunnelConfig.chain.remove(atOffsets: offsets)
                    }
                }
                .frame(minHeight: 60, maxHeight: 150)
            }

            // Add to chain button
            let availableForChain = appState.services.filter { service in
                !appState.tunnelConfig.chain.contains(service.id)
            }

            if !availableForChain.isEmpty {
                Menu {
                    ForEach(availableForChain) { service in
                        Button {
                            state.tunnelConfig.chain.append(service.id)
                        } label: {
                            Label(service.name, systemImage: service.protocol.systemImage)
                        }
                    }
                } label: {
                    Label("Add to Chain", systemImage: "plus.circle")
                }
            }

            if chainServices.count >= 2 {
                Text("Traffic routes: \(chainServices.map(\.name).joined(separator: " → "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Routing Rules Section

    private var routingRulesSection: some View {
        @Bindable var state = appState

        return Section {
            // Explanation
            Text("Rules are evaluated top-to-bottom, first match wins.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Enhanced rule list with groups
            RuleListView()
                .frame(minHeight: 200, maxHeight: 400)

            // Final outbound picker
            Picker("Unmatched traffic", selection: $state.tunnelConfig.finalOutbound) {
                ForEach(RuleOutbound.allCases) { outbound in
                    Label(outbound.displayName, systemImage: outbound.systemImage)
                        .tag(outbound)
                }
            }
            .pickerStyle(.segmented)

            Text("Traffic not matching any rule will go to: \(appState.tunnelConfig.finalOutbound.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            HStack {
                Label("Routing Rules", systemImage: "arrow.triangle.branch")
                Spacer()
                Button {
                    activeSheet = .presetManager
                } label: {
                    Label("Manage Presets", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - Validation Section

    private var validationSection: some View {
        Section {
            if validationResult.isValid, !validationResult.hasWarnings {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configuration valid")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(validationResult.issues) { issue in
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
            Label("Status", systemImage: validationResult.isValid ? "checkmark.shield" : "exclamationmark.shield")
        }
    }
}

// MARK: - Supporting Views

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
