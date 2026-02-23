//
//  RuleListView.swift
//  TunnelMaster
//
//  Category-based rule list with native macOS patterns.
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

    var body: some View {
        VStack(spacing: 0) {
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

    // MARK: - Rules List

    private var rulesList: some View {
        List(selection: $selectedRuleIds) {
            // Inline action bar
            Section {
                HStack(spacing: 6) {
                    TextField("Search rules...", text: $searchText)
                        .textFieldStyle(.roundedBorder)

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
                    .help("Add Rule")

                    if !selectedRuleIds.isEmpty {
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

                        Button {
                            selectedRuleIds.removeAll()
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .help("Deselect All")
                    }
                }
            }

            // Category sections
            ForEach(RuleCategory.allCases) { category in
                let categoryRules = filteredRules(for: category)
                if !categoryRules.isEmpty {
                    DisclosureGroup {
                        ForEach(categoryRules, id: \.id) { rule in
                            ruleRow(rule)
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        deleteRule(rule)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Edit") {
                                        activeSheet = .ruleBuilder(category: nil, existing: rule)
                                    }
                                    .tint(.blue)
                                }
                        }
                    } label: {
                        categoryLabel(category, count: categoryRules.count)
                    }
                }
            }

            // User groups section
            ForEach(appState.tunnelConfig.sortedGroups) { group in
                let groupRules = filteredRules(in: group.id)
                if !groupRules.isEmpty {
                    DisclosureGroup {
                        ForEach(groupRules, id: \.id) { rule in
                            ruleRow(rule)
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        deleteRule(rule)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Edit") {
                                        activeSheet = .ruleBuilder(category: nil, existing: rule)
                                    }
                                    .tint(.blue)
                                }
                        }
                    } label: {
                        Label {
                            HStack {
                                Text(group.name)
                                Spacer()
                                Text("\(groupRules.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: group.icon)
                                .foregroundStyle(group.color.swiftUIColor)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Category Label

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
