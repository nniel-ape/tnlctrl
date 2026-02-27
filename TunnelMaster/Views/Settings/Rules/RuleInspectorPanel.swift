//
//  RuleInspectorPanel.swift
//  TunnelMaster
//
//  Live-editing inspector panel for the selected routing rule.
//

import SwiftUI

struct RuleInspectorPanel: View {
    @Environment(AppState.self) private var appState
    let ruleId: UUID
    @State private var activeSheet: PickerSheet?

    enum PickerSheet: Identifiable {
        case app
        case domain
        case geoSite
        case geoIP
        case ipRange

        var id: Self {
            self
        }
    }

    private var ruleIndex: Int? {
        appState.tunnelConfig.rules.firstIndex(where: { $0.id == ruleId })
    }

    var body: some View {
        @Bindable var state = appState

        if let index = ruleIndex {
            let rule = appState.tunnelConfig.rules[index]

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(rule: rule, index: index)

                    if rule.type.category.ruleTypes.count > 1 {
                        Divider()
                        typeSection(rule: rule, index: index)
                    }

                    Divider()
                    valueSection(rule: rule, index: index)
                    Divider()
                    actionSection(index: index)
                    Divider()
                    organizationSection(rule: rule, index: index)

                    if let conflict = detectConflict(rule: rule) {
                        Divider()
                        conflictWarning(conflict)
                    }

                    Divider()
                    metadataSection(rule: rule)

                    Spacer()
                }
                .padding(16)
            }
            .sheet(item: $activeSheet) { sheet in
                pickerSheet(sheet, index: index)
            }
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "sidebar.right",
                description: Text("Select a rule to inspect")
            )
        }
    }

    // MARK: - Header

    private func header(rule: RoutingRule, index: Int) -> some View {
        @Bindable var state = appState

        return HStack(spacing: 8) {
            Image(systemName: rule.type.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.type.displayName)
                    .font(.headline)
                Text(rule.value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Toggle("", isOn: $state.tunnelConfig.rules[index].isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    // MARK: - Type

    private func typeSection(rule: RoutingRule, index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("TYPE")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("", selection: $state.tunnelConfig.rules[index].type) {
                ForEach(rule.type.category.ruleTypes, id: \.self) { type in
                    Text(type.shortName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Value

    private func valueSection(rule: RoutingRule, index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("VALUE")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                TextField(rule.type.placeholder, text: $state.tunnelConfig.rules[index].value)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                Button {
                    openVisualPicker(for: rule.type.category)
                } label: {
                    Image(systemName: "rectangle.and.hand.point.up.left")
                }
                .buttonStyle(.borderless)
                .help("Visual picker")
            }
        }
    }

    // MARK: - Action

    private func actionSection(index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("ACTION")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("", selection: $state.tunnelConfig.rules[index].outbound) {
                ForEach(RuleOutbound.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Organization

    private func organizationSection(rule: RoutingRule, index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("ORGANIZATION")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("Group", selection: $state.tunnelConfig.rules[index].groupId) {
                Text("Ungrouped").tag(UUID?.none)
                if !appState.tunnelConfig.groups.isEmpty {
                    Divider()
                    ForEach(appState.tunnelConfig.sortedGroups) { group in
                        Label(group.name, systemImage: group.icon)
                            .tag(UUID?.some(group.id))
                    }
                }
            }
            .controlSize(.small)

            TextField("Note", text: noteBinding(index: index))
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    // MARK: - Conflict Detection

    private func detectConflict(rule: RoutingRule) -> RuleConflictDetector.Conflict? {
        let otherRules = appState.tunnelConfig.rules.filter { $0.id != rule.id }
        return RuleConflictDetector.detectConflictForNewRule(rule, in: otherRules)
    }

    private func conflictWarning(_ conflict: RuleConflictDetector.Conflict) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: conflict.severity == .error
                ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(conflict.severity == .error ? .red : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(conflict.explanation)
                    .font(.caption)
                Text(conflict.suggestion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Metadata

    private func metadataSection(rule: RoutingRule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("METADATA")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            LabeledContent("Created") {
                Text(rule.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            LabeledContent("Modified") {
                Text(rule.lastModified, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    // MARK: - Helpers

    private func noteBinding(index: Int) -> Binding<String> {
        Binding(
            get: { appState.tunnelConfig.rules[index].note ?? "" },
            set: { newValue in
                appState.tunnelConfig.rules[index].note = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private func openVisualPicker(for category: RuleCategory) {
        switch category {
        case .app: activeSheet = .app
        case .domain: activeSheet = .domain
        case .geoSite: activeSheet = .geoSite
        case .geoIP: activeSheet = .geoIP
        case .ip: activeSheet = .ipRange
        }
    }

    @ViewBuilder
    private func pickerSheet(_ sheet: PickerSheet, index: Int) -> some View {
        switch sheet {
        case .app:
            AppPickerView { processName, type in
                appState.tunnelConfig.rules[index].value = processName
                appState.tunnelConfig.rules[index].type = type
            }
        case .domain:
            DomainInputView { domain, type in
                appState.tunnelConfig.rules[index].value = domain
                appState.tunnelConfig.rules[index].type = type
            }
        case .geoSite:
            GeoSiteBrowserView { category in
                appState.tunnelConfig.rules[index].value = category
                appState.tunnelConfig.rules[index].type = .geosite
            }
        case .geoIP:
            GeoIPBrowserView { country in
                appState.tunnelConfig.rules[index].value = country
                appState.tunnelConfig.rules[index].type = .geoip
            }
        case .ipRange:
            IPRangeInputView { cidr in
                appState.tunnelConfig.rules[index].value = cidr
                appState.tunnelConfig.rules[index].type = .ipCidr
            }
        }
    }
}
