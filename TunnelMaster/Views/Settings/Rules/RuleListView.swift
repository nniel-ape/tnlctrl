//
//  RuleListView.swift
//  TunnelMaster
//
//  Enhanced rule list with groups, search, filtering, and bulk operations.
//

import SwiftUI

struct RuleListView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedRuleIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var filterTag: String?
    @State private var activeSheet: SheetDestination?

    enum SheetDestination: Identifiable {
        case groupManager
        case ruleBuilder(existing: RoutingRule?)

        var id: String {
            switch self {
            case .groupManager: return "groupManager"
            case let .ruleBuilder(rule): return "ruleBuilder-\(rule?.id.uuidString ?? "new")"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main content
            VStack(spacing: 0) {
                // Spacer for search bar
                Color.clear
                    .frame(height: 44)

                // Grouped rule list
                if filteredRules.isEmpty {
                    ContentUnavailableView(
                        "No Rules",
                        systemImage: "list.bullet.rectangle",
                        description: Text(searchText.isEmpty ? "Add rules to control routing" : "No rules match '\(searchText)'")
                    )
                } else {
                    rulesList
                }

                // Spacer for toolbar
                if !selectedRuleIds.isEmpty {
                    Color.clear
                        .frame(height: 52)
                }
            }

            // Search bar overlay
            VStack(spacing: 0) {
                searchBar
                    .background(.bar)
                Divider()
                Spacer()
            }

            // Bulk actions toolbar overlay
            if !selectedRuleIds.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    Divider()
                    BulkActionsToolbar(
                        selectedCount: selectedRuleIds.count,
                        groups: appState.tunnelConfig.groups,
                        onEnable: { enableSelected() },
                        onDisable: { disableSelected() },
                        onChangeOutbound: { outbound in changeOutboundForSelected(outbound) },
                        onMoveToGroup: { groupId in moveSelectedToGroup(groupId) },
                        onAddTag: { tag in addTagToSelected(tag) },
                        onDelete: { deleteSelected() },
                        onClearSelection: { selectedRuleIds.removeAll() }
                    )
                }
            }
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .groupManager:
                GroupManagerSheet()
            case let .ruleBuilder(existingRule):
                RuleBuilderSheet(existingRule: existingRule)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search rules...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 16)

            // Tag filter
            Menu {
                Button("All") { filterTag = nil }
                if !allTags.isEmpty {
                    Divider()
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) { filterTag = tag }
                    }
                }
            } label: {
                Label(filterTag ?? "All Tags", systemImage: "tag")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Group manager button
            Button {
                activeSheet = .groupManager
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .buttonStyle(.borderless)
            .help("Manage Groups")

            // Add rule button
            Button {
                activeSheet = .ruleBuilder(existing: nil)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("Add Rule")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List(selection: $selectedRuleIds) {
            // Groups
            ForEach(appState.tunnelConfig.sortedGroups) { group in
                let groupRules = filteredRules(in: group.id)
                if !groupRules.isEmpty {
                    Section {
                        if group.isExpanded {
                            ForEach(Array(groupRules.enumerated()), id: \.element.id) { _, rule in
                                ruleRow(rule)
                            }
                            .onMove { from, to in
                                moveRulesInGroup(group.id, from: from, to: to)
                            }
                        }
                    } header: {
                        RuleGroupHeader(
                            group: binding(for: group),
                            ruleCount: groupRules.count
                        )
                    }
                }
            }

            // Ungrouped rules
            let ungrouped = filteredUngroupedRules
            if !ungrouped.isEmpty {
                Section("Ungrouped") {
                    ForEach(Array(ungrouped.enumerated()), id: \.element.id) { _, rule in
                        ruleRow(rule)
                    }
                    .onMove { from, to in
                        moveUngroupedRules(from: from, to: to)
                    }
                }
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
    }

    private func ruleRow(_ rule: RoutingRule) -> some View {
        RuleItemRow(
            rule: binding(for: rule),
            onDelete: { deleteRule(rule) },
            onEdit: {
                activeSheet = .ruleBuilder(existing: rule)
            }
        )
        .tag(rule.id)
    }

    // MARK: - Filtering

    private var filteredRules: [RoutingRule] {
        appState.tunnelConfig.rules
            .filter { matchesSearch($0) }
            .filter { matchesTagFilter($0) }
    }

    private func filteredRules(in groupId: UUID) -> [RoutingRule] {
        appState.tunnelConfig.rules(in: groupId)
            .filter { matchesSearch($0) }
            .filter { matchesTagFilter($0) }
    }

    private var filteredUngroupedRules: [RoutingRule] {
        appState.tunnelConfig.ungroupedRules
            .filter { matchesSearch($0) }
            .filter { matchesTagFilter($0) }
    }

    private func matchesSearch(_ rule: RoutingRule) -> Bool {
        guard !searchText.isEmpty else { return true }
        return rule.value.localizedCaseInsensitiveContains(searchText) ||
            rule.type.displayName.localizedCaseInsensitiveContains(searchText) ||
            (rule.note?.localizedCaseInsensitiveContains(searchText) ?? false)
    }

    private func matchesTagFilter(_ rule: RoutingRule) -> Bool {
        guard let tag = filterTag else { return true }
        return rule.tags.contains(tag)
    }

    private var allTags: [String] {
        let tags = appState.tunnelConfig.rules.flatMap(\.tags)
        return Array(Set(tags)).sorted()
    }

    // MARK: - Bulk Operations

    private func enableSelected() {
        appState.tunnelConfig.enableRules(selectedRuleIds)
    }

    private func disableSelected() {
        appState.tunnelConfig.disableRules(selectedRuleIds)
    }

    private func changeOutboundForSelected(_ outbound: RuleOutbound) {
        appState.tunnelConfig.setOutbound(outbound, for: selectedRuleIds)
    }

    private func moveSelectedToGroup(_ groupId: UUID?) {
        appState.tunnelConfig.moveRulesToGroup(groupId, ids: selectedRuleIds)
    }

    private func addTagToSelected(_ tag: String) {
        appState.tunnelConfig.addTag(tag, to: selectedRuleIds)
    }

    private func deleteSelected() {
        appState.tunnelConfig.rules.removeAll { selectedRuleIds.contains($0.id) }
        selectedRuleIds.removeAll()
    }

    private func deleteRule(_ rule: RoutingRule) {
        appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
        selectedRuleIds.remove(rule.id)
    }

    // MARK: - Reordering

    private func moveRulesInGroup(_ groupId: UUID, from: IndexSet, to: Int) {
        var groupRules = appState.tunnelConfig.rules(in: groupId)
        groupRules.move(fromOffsets: from, toOffset: to)

        // Update positions in the main array
        var nonGroupRules = appState.tunnelConfig.rules.filter { $0.groupId != groupId }
        // Find insertion point
        if let firstGroupRuleIndex = appState.tunnelConfig.rules.firstIndex(where: { $0.groupId == groupId }) {
            nonGroupRules.insert(contentsOf: groupRules, at: firstGroupRuleIndex)
        }
        appState.tunnelConfig.rules = nonGroupRules
    }

    private func moveUngroupedRules(from: IndexSet, to: Int) {
        var ungroupedRules = appState.tunnelConfig.ungroupedRules
        ungroupedRules.move(fromOffsets: from, toOffset: to)

        // Update positions in the main array
        var groupedRules = appState.tunnelConfig.rules.filter { $0.groupId != nil }
        groupedRules.append(contentsOf: ungroupedRules)
        appState.tunnelConfig.rules = groupedRules
    }

    // MARK: - Helpers

    private func binding(for rule: RoutingRule) -> Binding<RoutingRule> {
        guard let index = appState.tunnelConfig.rules.firstIndex(where: { $0.id == rule.id }) else {
            fatalError("Rule not found in array")
        }
        return Binding(
            get: { appState.tunnelConfig.rules[index] },
            set: { appState.tunnelConfig.rules[index] = $0 }
        )
    }

    private func binding(for group: RuleGroup) -> Binding<RuleGroup> {
        guard let index = appState.tunnelConfig.groups.firstIndex(where: { $0.id == group.id }) else {
            fatalError("Group not found in array")
        }
        return Binding(
            get: { appState.tunnelConfig.groups[index] },
            set: { appState.tunnelConfig.groups[index] = $0 }
        )
    }
}
