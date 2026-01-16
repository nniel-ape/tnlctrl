//
//  TunnelTab.swift
//  TunnelMaster
//

import SwiftUI

struct TunnelTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingRuleSheet = false
    @State private var editingRule: RoutingRule?

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
        .onChange(of: appState.tunnelConfig) {
            appState.saveTunnelConfig()
        }
        .sheet(isPresented: $showingRuleSheet) {
            RuleEditSheet(rule: editingRule) { rule in
                if let existing = editingRule {
                    if let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == existing.id }) {
                        appState.tunnelConfig.rules[index] = rule
                    }
                } else {
                    appState.tunnelConfig.rules.append(rule)
                }
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
                // Chain visualization
                HStack(spacing: 4) {
                    ForEach(Array(chainServices.enumerated()), id: \.element.id) { index, service in
                        HStack(spacing: 4) {
                            ChainServiceBadge(service: service, index: index + 1) {
                                state.tunnelConfig.chain.removeAll { $0 == service.id }
                            }
                            if index < chainServices.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
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
            // Presets
            presetsRow

            // Explanation
            Text("Rules are evaluated top-to-bottom, first match wins.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Rules list
            if appState.tunnelConfig.rules.isEmpty {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.secondary)
                    Text("No rules configured")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(state.tunnelConfig.rules) { rule in
                        RuleRow(rule: rule)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingRule = rule
                                showingRuleSheet = true
                            }
                            .contextMenu {
                                Button {
                                    editingRule = rule
                                    showingRuleSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button {
                                    // Duplicate rule
                                    let newRule = RoutingRule(
                                        type: rule.type,
                                        value: rule.value,
                                        outbound: rule.outbound
                                    )
                                    state.tunnelConfig.rules.append(newRule)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    state.tunnelConfig.rules.removeAll { $0.id == rule.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        state.tunnelConfig.rules.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        state.tunnelConfig.rules.move(fromOffsets: from, toOffset: to)
                    }
                }
                .frame(minHeight: 100, maxHeight: 250)
            }

            // Add rule button
            Button {
                editingRule = nil
                showingRuleSheet = true
            } label: {
                Label("Add Rule", systemImage: "plus.circle")
            }

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
            Label("Routing Rules", systemImage: "arrow.triangle.branch")
        }
    }

    private var presetsRow: some View {
        @Bindable var state = appState

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RulePreset.builtInPresets) { preset in
                    PresetChip(preset: preset) {
                        // Add preset rules, avoiding duplicates
                        for rule in preset.rules {
                            let exists = state.tunnelConfig.rules.contains {
                                $0.type == rule.type && $0.value.lowercased() == rule.value.lowercased()
                            }
                            if !exists {
                                state.tunnelConfig.rules.append(rule)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Validation Section

    private var validationSection: some View {
        let result = TunnelConfigValidator.validate(
            config: appState.tunnelConfig,
            services: appState.services
        )

        return Section {
            if result.isValid && !result.hasWarnings {
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

// MARK: - Supporting Views

private struct ChainServiceBadge: View {
    let service: Service
    let index: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(index).")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(systemName: service.protocol.systemImage)
                .font(.caption)
            Text(service.name)
                .font(.caption)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.secondary.opacity(0.15))
        .clipShape(Capsule())
    }
}

private struct PresetChip: View {
    let preset: RulePreset
    let onApply: () -> Void

    var body: some View {
        Button {
            onApply()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text(preset.name)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(preset.description)
    }
}

private struct RuleRow: View {
    let rule: RoutingRule

    var body: some View {
        HStack {
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Rule type badge
            Text(rule.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.2))
                .foregroundStyle(badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Value
            Text(rule.value)
                .lineLimit(1)

            Spacer()

            // Outbound indicator
            Image(systemName: rule.outbound.systemImage)
                .foregroundStyle(outboundColor)
            Text(rule.outbound.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var badgeColor: Color {
        switch rule.type {
        case .domain, .domainSuffix, .domainKeyword:
            .purple
        case .ipCidr:
            .orange
        case .geoip, .geosite:
            .teal
        case .processName, .processPath:
            .gray
        }
    }

    private var outboundColor: Color {
        switch rule.outbound {
        case .direct: .green
        case .proxy: .blue
        case .block: .red
        }
    }
}
