//
//  RuleBuilderSheet.swift
//  TunnelMaster
//
//  Streamlined rule builder for adding new rules. Editing happens in the inspector.
//

import SwiftUI

struct RuleBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let initialCategory: RuleCategory
    private let onCreated: ((UUID) -> Void)?

    @State private var selectedCategory: RuleCategory
    @State private var selectedRuleType: RuleType
    @State private var ruleValue = ""
    @State private var outbound: RuleOutbound = .proxy
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

    init(category: RuleCategory = .domain, onCreated: ((UUID) -> Void)? = nil) {
        self.initialCategory = category
        self.onCreated = onCreated
        _selectedCategory = State(initialValue: category)
        _selectedRuleType = State(initialValue: category.ruleTypes[0])
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
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(ruleValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 400, height: 340)
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

        return RuleConflictDetector.detectConflictForNewRule(tempRule, in: appState.tunnelConfig.rules)
    }

    // MARK: - Save

    private func save() {
        let newId = UUID()
        let rule = RoutingRule(
            id: newId,
            type: selectedRuleType,
            value: ruleValue.trimmingCharacters(in: .whitespaces),
            outbound: outbound,
            isEnabled: true,
            createdAt: Date(),
            lastModified: Date()
        )

        appState.tunnelConfig.rules.append(rule)
        onCreated?(newId)
        dismiss()
    }
}
