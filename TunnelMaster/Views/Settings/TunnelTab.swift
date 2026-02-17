//
//  TunnelTab.swift
//  TunnelMaster
//

import SwiftUI

struct TunnelTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingRuleSheet = false
    @State private var editingRule: RoutingRule?
    @State private var showingPresetManager = false
    @State private var selectedRuleId: UUID?

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
            RuleBuilderSheet(rule: editingRule) { rule in
                if let existing = editingRule {
                    if let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == existing.id }) {
                        appState.tunnelConfig.rules[index] = rule
                    } else {
                        // Rule was deleted while editing — save as new rule
                        appState.tunnelConfig.rules.append(rule)
                    }
                } else {
                    appState.tunnelConfig.rules.append(rule)
                }
            }
        }
        .sheet(isPresented: $showingPresetManager) {
            PresetManagerSheet()
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

            // Rules list
            if appState.tunnelConfig.rules.isEmpty {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.secondary)
                    Text("No rules configured")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Rules summary
                let enabledCount = appState.tunnelConfig.rules.filter(\.isEnabled).count
                let totalCount = appState.tunnelConfig.rules.count
                if enabledCount < totalCount {
                    Text("\(enabledCount) of \(totalCount) rules enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                List(selection: $selectedRuleId) {
                    ForEach(Array(state.tunnelConfig.rules.enumerated()), id: \.element.id) { _, rule in
                        RuleRow(
                            rule: rule,
                            isEnabled: Binding(
                                get: { state.tunnelConfig.rules.first(where: { $0.id == rule.id })?.isEnabled ?? true },
                                set: { newValue in
                                    if let idx = state.tunnelConfig.rules.firstIndex(where: { $0.id == rule.id }) {
                                        state.tunnelConfig.rules[idx].isEnabled = newValue
                                    }
                                }
                            )
                        )
                        .tag(rule.id)
                    }
                    .onDelete { offsets in
                        state.tunnelConfig.rules.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        state.tunnelConfig.rules.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
                .contextMenu(
                    forSelectionType: UUID.self,
                    menu: { ids in
                        if let id = ids.first,
                           let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
                            ruleContextMenu(for: appState.tunnelConfig.rules[index], at: index)
                        }
                    },
                    primaryAction: { ids in
                        // Double-click opens edit sheet
                        if let id = ids.first,
                           let rule = appState.tunnelConfig.rules.first(where: { $0.id == id }) {
                            editingRule = rule
                            showingRuleSheet = true
                        }
                    }
                )
                .frame(minHeight: 100, maxHeight: 250)
                .onDeleteCommand {
                    if let selectedId = selectedRuleId {
                        appState.tunnelConfig.rules.removeAll { $0.id == selectedId }
                        selectedRuleId = nil
                    }
                }
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
            HStack {
                Label("Routing Rules", systemImage: "arrow.triangle.branch")
                Spacer()
                Button {
                    showingPresetManager = true
                } label: {
                    Label("Manage Presets", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: - Rule Context Menu

    @ViewBuilder
    private func ruleContextMenu(
        for rule: RoutingRule,
        at index: Int
    ) -> some View {
        Button {
            appState.tunnelConfig.rules[index].isEnabled.toggle()
        } label: {
            Label(
                rule.isEnabled ? "Disable" : "Enable",
                systemImage: rule.isEnabled ? "eye.slash" : "eye"
            )
        }

        Button {
            editingRule = rule
            showingRuleSheet = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            let newRule = RoutingRule(
                type: rule.type,
                value: rule.value,
                outbound: rule.outbound,
                isEnabled: rule.isEnabled,
                note: rule.note
            )
            appState.tunnelConfig.rules.append(newRule)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
            selectedRuleId = nil
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Validation Section

    private var validationSection: some View {
        let result = TunnelConfigValidator.validate(
            config: appState.tunnelConfig,
            services: appState.services
        )

        return Section {
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

private struct RuleRow: View {
    let rule: RoutingRule
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox (native macOS for list items)
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            // Rule type icon
            Image(systemName: rule.type.systemImage)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            // Value & note
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.value)
                    .lineLimit(1)
                if let note = rule.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isEnabled ? .primary : .tertiary)

            Spacer()

            // Rule type (text only, no badge)
            Text(rule.type.displayName)
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Outbound indicator
            Text(rule.outbound.displayName)
                .font(.caption)
                .foregroundStyle(isEnabled ? outboundColor : Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private var outboundColor: Color {
        switch rule.outbound {
        case .direct: .green
        case .proxy: .blue
        case .block: .red
        }
    }
}
