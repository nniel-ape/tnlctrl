//
//  RuleInspectorPanel.swift
//  tnl_ctrl
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

    private func ruleBinding() -> Binding<RoutingRule>? {
        guard let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == ruleId }) else {
            return nil
        }
        @Bindable var state = appState
        return $state.tunnelConfig.rules[index]
    }

    var body: some View {
        if let rule = ruleBinding() {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(rule: rule)

                    if rule.wrappedValue.type.category.ruleTypes.count > 1 {
                        Divider()
                        typeSection(rule: rule)
                    }

                    Divider()
                    valueSection(rule: rule)
                    Divider()
                    actionSection(rule: rule)
                    Divider()
                    organizationSection(rule: rule)

                    if let conflict = detectConflict(rule: rule.wrappedValue) {
                        Divider()
                        conflictWarning(conflict)
                    }

                    Divider()
                    metadataSection(rule: rule.wrappedValue)

                    Spacer()
                }
                .padding(16)
            }
            .sheet(item: $activeSheet) { sheet in
                pickerSheet(sheet, rule: rule)
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

    private func header(rule: Binding<RoutingRule>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: rule.wrappedValue.type.systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.wrappedValue.type.displayName)
                    .font(.headline)
                Text(rule.wrappedValue.value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Toggle("", isOn: rule.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    // MARK: - Type

    private func typeSection(rule: Binding<RoutingRule>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TYPE")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("", selection: rule.type) {
                ForEach(rule.wrappedValue.type.category.ruleTypes, id: \.self) { type in
                    Text(type.shortName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Value

    private func valueSection(rule: Binding<RoutingRule>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VALUE")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                TextField(rule.wrappedValue.type.placeholder, text: rule.value)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())

                Button {
                    openVisualPicker(for: rule.wrappedValue.type.category)
                } label: {
                    Image(systemName: "rectangle.and.hand.point.up.left")
                }
                .buttonStyle(.borderless)
                .help("Visual picker")
            }
        }
    }

    // MARK: - Action

    private func actionSection(rule: Binding<RoutingRule>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTION")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("", selection: rule.outbound) {
                ForEach(RuleOutbound.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Organization

    private func organizationSection(rule: Binding<RoutingRule>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ORGANIZATION")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("Group", selection: rule.groupId) {
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

            TextField("Note", text: noteBinding(rule: rule))
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

    private func noteBinding(rule: Binding<RoutingRule>) -> Binding<String> {
        Binding(
            get: { rule.wrappedValue.note ?? "" },
            set: { newValue in
                rule.wrappedValue.note = newValue.isEmpty ? nil : newValue
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
    private func pickerSheet(_ sheet: PickerSheet, rule: Binding<RoutingRule>) -> some View {
        switch sheet {
        case .app:
            AppPickerView { processName, type in
                rule.wrappedValue.value = processName
                rule.wrappedValue.type = type
            }
        case .domain:
            DomainInputView { domain, type in
                rule.wrappedValue.value = domain
                rule.wrappedValue.type = type
            }
        case .geoSite:
            GeoSiteBrowserView { category in
                rule.wrappedValue.value = category
                rule.wrappedValue.type = .geosite
            }
        case .geoIP:
            GeoIPBrowserView { country in
                rule.wrappedValue.value = country
                rule.wrappedValue.type = .geoip
            }
        case .ipRange:
            IPRangeInputView { cidr in
                rule.wrappedValue.value = cidr
                rule.wrappedValue.type = .ipCidr
            }
        }
    }
}
