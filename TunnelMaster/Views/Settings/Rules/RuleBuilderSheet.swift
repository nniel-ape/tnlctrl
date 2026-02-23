//
//  RuleBuilderSheet.swift
//  TunnelMaster
//
//  Single-page rule builder with native Form layout.
//

import SwiftUI

struct RuleBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedCategory: RuleCategory
    @State private var selectedRuleType: RuleType
    @State private var ruleValue: String
    @State private var outbound: RuleOutbound
    @State private var note: String
    @State private var selectedGroupId: UUID?

    @State private var activeSheet: PickerSheet?

    private let existingRule: RoutingRule?

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

    init(category: RuleCategory? = nil, existingRule: RoutingRule? = nil) {
        self.existingRule = existingRule

        if let rule = existingRule {
            _selectedCategory = State(initialValue: rule.type.category)
            _selectedRuleType = State(initialValue: rule.type)
            _ruleValue = State(initialValue: rule.value)
            _outbound = State(initialValue: rule.outbound)
            _note = State(initialValue: rule.note ?? "")
            _selectedGroupId = State(initialValue: rule.groupId)
        } else {
            let cat = category ?? .domain
            _selectedCategory = State(initialValue: cat)
            _selectedRuleType = State(initialValue: cat.ruleTypes[0])
            _ruleValue = State(initialValue: "")
            _outbound = State(initialValue: .proxy)
            _note = State(initialValue: "")
            _selectedGroupId = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Rule Type
                Section("Rule Type") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(RuleCategory.allCases) { category in
                            Label(category.displayName, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }
                    .onChange(of: selectedCategory) { _, newValue in
                        selectedRuleType = newValue.ruleTypes[0]
                    }

                    if selectedCategory.ruleTypes.count > 1 {
                        Picker("Sub-type", selection: $selectedRuleType) {
                            ForEach(selectedCategory.ruleTypes, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Value
                Section("Value") {
                    HStack {
                        TextField(selectedRuleType.placeholder, text: $ruleValue)
                            .font(.body.monospaced())

                        Button {
                            openVisualPicker()
                        } label: {
                            Image(systemName: "rectangle.and.hand.point.up.left")
                        }
                        .buttonStyle(.borderless)
                        .help("Use visual picker")
                    }

                    Text(ruleTypeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Action
                Section("Action") {
                    Picker("Route to", selection: $outbound) {
                        ForEach(RuleOutbound.allCases) { action in
                            Label(action.displayName, systemImage: action.systemImage)
                                .tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Organization
                Section("Organization") {
                    Picker("Group", selection: $selectedGroupId) {
                        Text("Ungrouped").tag(UUID?.none)
                        if !appState.tunnelConfig.groups.isEmpty {
                            Divider()
                            ForEach(appState.tunnelConfig.sortedGroups) { group in
                                Label(group.name, systemImage: group.icon)
                                    .tag(UUID?.some(group.id))
                            }
                        }
                    }

                    TextField("Note (optional)", text: $note)
                }

                // Conflict warning
                if let conflict = potentialConflict {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: conflict.severity == .error
                                ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(conflict.severity == .error ? .red : .orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conflict.explanation)
                                    .font(.callout)
                                Text(conflict.suggestion)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingRule == nil ? "Add Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(ruleValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 420, height: 420)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .app:
                AppPickerView { processName, type in
                    ruleValue = processName
                    selectedRuleType = type
                }
            case .domain:
                DomainInputView { domain, type in
                    ruleValue = domain
                    selectedRuleType = type
                }
            case .geoSite:
                GeoSiteBrowserView { category in
                    ruleValue = category
                    selectedRuleType = .geosite
                }
            case .geoIP:
                GeoIPBrowserView { country in
                    ruleValue = country
                    selectedRuleType = .geoip
                }
            case .ipRange:
                IPRangeInputView { cidr in
                    ruleValue = cidr
                    selectedRuleType = .ipCidr
                }
            }
        }
    }

    // MARK: - Visual Picker

    private func openVisualPicker() {
        switch selectedCategory {
        case .app: activeSheet = .app
        case .domain: activeSheet = .domain
        case .geoSite: activeSheet = .geoSite
        case .geoIP: activeSheet = .geoIP
        case .ip: activeSheet = .ipRange
        }
    }

    // MARK: - Descriptions

    private var ruleTypeDescription: String {
        switch selectedRuleType {
        case .processName:
            "Match traffic from apps by process name (e.g., 'Safari')"
        case .processPath:
            "Match traffic from apps by full executable path"
        case .domain:
            "Match exact domain name only"
        case .domainSuffix:
            "Match domain and all its subdomains"
        case .domainKeyword:
            "Match any domain containing this keyword"
        case .ipCidr:
            "Match IP addresses in this CIDR range"
        case .geoip:
            "Match traffic to this country (requires geoip.db)"
        case .geosite:
            "Match traffic to this site category (requires geosite.db)"
        }
    }

    // MARK: - Conflict Detection

    private var potentialConflict: RuleConflictDetector.Conflict? {
        guard !ruleValue.isEmpty else { return nil }

        let tempRule = RoutingRule(
            type: selectedRuleType,
            value: ruleValue,
            outbound: outbound,
            isEnabled: true
        )

        let rulesToCheck = appState.tunnelConfig.rules.filter {
            $0.id != existingRule?.id
        }

        return RuleConflictDetector.detectConflictForNewRule(tempRule, in: rulesToCheck)
    }

    // MARK: - Save

    private func save() {
        let rule = RoutingRule(
            id: existingRule?.id ?? UUID(),
            type: selectedRuleType,
            value: ruleValue.trimmingCharacters(in: .whitespaces),
            outbound: outbound,
            isEnabled: existingRule?.isEnabled ?? true,
            note: note.isEmpty ? nil : note,
            groupId: selectedGroupId,
            tags: existingRule?.tags ?? [],
            createdAt: existingRule?.createdAt ?? Date(),
            lastModified: Date()
        )

        if let existing = existingRule {
            if let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == existing.id }) {
                appState.tunnelConfig.rules[index] = rule
            } else {
                appState.tunnelConfig.rules.append(rule)
            }
        } else {
            appState.tunnelConfig.rules.append(rule)
        }

        dismiss()
    }
}
