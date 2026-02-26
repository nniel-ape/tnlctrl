//
//  RuleListView.swift
//  TunnelMaster
//
//  Category-based rule list with extracted toolbar and unified organization.
//

import SwiftUI

struct RuleListView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedRuleIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var activeSheet: SheetDestination?

    enum SheetDestination: Identifiable {
        case groupManager
        case ruleBuilder(category: RuleCategory?, existing: RoutingRule?)

        var id: String {
            switch self {
            case .groupManager: "groupManager"
            case let .ruleBuilder(cat, rule):
                "ruleBuilder-\(cat?.rawValue ?? "nil")-\(rule?.id.uuidString ?? "new")"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if filteredRules.isEmpty, searchText.isEmpty {
                ContentUnavailableView(
                    "No Rules",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Add rules to control routing")
                )
            } else if filteredRules.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No rules match '\(searchText)'")
                )
            } else {
                rulesList
            }
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .groupManager:
                GroupManagerSheet()
            case let .ruleBuilder(category, existingRule):
                RuleBuilderSheet(category: category, existingRule: existingRule)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search rules...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if !selectedRuleIds.isEmpty {
                bulkActionsMenu
            }

            Spacer()

            Button {
                activeSheet = .groupManager
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .help("Manage Groups")

            Menu {
                ForEach(RuleCategory.allCases) { category in
                    Button {
                        activeSheet = .ruleBuilder(category: category, existing: nil)
                    } label: {
                        Label(category.displayName, systemImage: category.systemImage)
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuIndicator(.hidden)
            .help("Add Rule")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Bulk Actions

    private var bulkActionsMenu: some View {
        Menu {
            Button {
                appState.tunnelConfig.enableRules(selectedRuleIds)
            } label: {
                Label("Enable", systemImage: "eye")
            }
            Button {
                appState.tunnelConfig.disableRules(selectedRuleIds)
            } label: {
                Label("Disable", systemImage: "eye.slash")
            }

            Divider()

            Menu("Set Outbound") {
                ForEach(RuleOutbound.allCases) { outbound in
                    Button {
                        appState.tunnelConfig.setOutbound(outbound, for: selectedRuleIds)
                    } label: {
                        Label(outbound.displayName, systemImage: outbound.systemImage)
                    }
                }
            }

            Menu("Move to Group") {
                Button("Ungrouped") {
                    appState.tunnelConfig.moveRulesToGroup(nil, ids: selectedRuleIds)
                }
                if !appState.tunnelConfig.groups.isEmpty {
                    Divider()
                    ForEach(appState.tunnelConfig.sortedGroups) { group in
                        Button {
                            appState.tunnelConfig.moveRulesToGroup(group.id, ids: selectedRuleIds)
                        } label: {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                appState.tunnelConfig.rules.removeAll { selectedRuleIds.contains($0.id) }
                selectedRuleIds.removeAll()
            }
        } label: {
            Label("Actions (\(selectedRuleIds.count))", systemImage: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List(selection: $selectedRuleIds) {
            let hasGroups = !appState.tunnelConfig.groups.isEmpty

            if hasGroups {
                // Groups first, then ungrouped by category
                ForEach(appState.tunnelConfig.sortedGroups) { group in
                    let groupRules = filteredRules(in: group.id)
                    if !groupRules.isEmpty {
                        DisclosureGroup {
                            ForEach(groupRules, id: \.id) { rule in
                                ruleRow(rule)
                            }
                        } label: {
                            groupLabel(group, count: groupRules.count)
                        }
                    }
                }

                // Ungrouped rules by category
                ForEach(RuleCategory.allCases) { category in
                    let ungrouped = filteredUngroupedRules(for: category)
                    if !ungrouped.isEmpty {
                        DisclosureGroup {
                            ForEach(ungrouped, id: \.id) { rule in
                                ruleRow(rule)
                            }
                        } label: {
                            categoryLabel(category, count: ungrouped.count)
                        }
                    }
                }
            } else {
                // No groups — show all rules by category
                ForEach(RuleCategory.allCases) { category in
                    let categoryRules = filteredRules(for: category)
                    if !categoryRules.isEmpty {
                        DisclosureGroup {
                            ForEach(categoryRules, id: \.id) { rule in
                                ruleRow(rule)
                            }
                        } label: {
                            categoryLabel(category, count: categoryRules.count)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Labels

    private func categoryLabel(_ category: RuleCategory, count: Int) -> some View {
        Label {
            HStack {
                Text(category.displayName)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: category.systemImage)
        }
    }

    private func groupLabel(_ group: RuleGroup, count: Int) -> some View {
        Label {
            HStack {
                Text(group.name)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: group.icon)
                .foregroundStyle(group.color.swiftUIColor)
        }
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: RoutingRule) -> some View {
        NativeRuleRow(
            rule: rule,
            onToggleEnabled: { toggleRuleEnabled(rule.id) },
            onDelete: { deleteRule(rule) },
            onEdit: {
                activeSheet = .ruleBuilder(category: nil, existing: rule)
            }
        )
        .tag(rule.id)
    }

    // MARK: - Filtering

    private var filteredRules: [RoutingRule] {
        appState.tunnelConfig.rules.filter { matchesSearch($0) }
    }

    private func filteredRules(for category: RuleCategory) -> [RoutingRule] {
        appState.tunnelConfig.rules(for: category).filter { matchesSearch($0) }
    }

    private func filteredRules(in groupId: UUID) -> [RoutingRule] {
        appState.tunnelConfig.rules(in: groupId).filter { matchesSearch($0) }
    }

    /// Ungrouped rules filtered by category (for unified display when groups exist)
    private func filteredUngroupedRules(for category: RuleCategory) -> [RoutingRule] {
        appState.tunnelConfig.ungroupedRules
            .filter { $0.type.category == category && matchesSearch($0) }
    }

    private func matchesSearch(_ rule: RoutingRule) -> Bool {
        guard !searchText.isEmpty else { return true }
        return rule.value.localizedCaseInsensitiveContains(searchText) ||
            rule.type.displayName.localizedCaseInsensitiveContains(searchText) ||
            (rule.note?.localizedCaseInsensitiveContains(searchText) ?? false)
    }

    // MARK: - Actions

    private func deleteRule(_ rule: RoutingRule) {
        appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
        selectedRuleIds.remove(rule.id)
    }

    private func toggleRuleEnabled(_ id: UUID) {
        if let i = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
            appState.tunnelConfig.rules[i].isEnabled.toggle()
        }
    }
}
