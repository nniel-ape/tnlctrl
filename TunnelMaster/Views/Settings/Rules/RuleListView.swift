//
//  RuleListView.swift
//  TunnelMaster
//
//  Grouped rule list with inline group headers, bottom toolbar, and status bar.
//

import SwiftUI

struct RuleListView: View {
    @Environment(AppState.self) private var appState

    @Binding var selection: RuleListSelection?
    @Binding var selectedItems: Set<RuleListSelection>

    @State private var searchText = ""
    @State private var categoryFilter: RuleCategory?
    @State private var activeSheet: SheetDestination?

    enum SheetDestination: Identifiable {
        case ruleBuilder(category: RuleCategory)

        var id: String {
            switch self {
            case let .ruleBuilder(cat): "ruleBuilder-\(cat.rawValue)"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if appState.tunnelConfig.rules.isEmpty, searchText.isEmpty, categoryFilter == nil {
                ContentUnavailableView(
                    "No Rules",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Add rules to control routing")
                )
            } else if visibleItemCount == 0, !searchText.isEmpty || categoryFilter != nil {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No rules match the current filter")
                )
            } else {
                rulesList
            }

            Divider()
            bottomBar
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case let .ruleBuilder(category):
                RuleBuilderSheet(category: category) { newRuleId in
                    selection = .rule(newRuleId)
                    selectedItems = [.rule(newRuleId)]
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
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

            // Category filter
            Menu {
                Button {
                    categoryFilter = nil
                } label: {
                    Label("All Categories", systemImage: "line.3.horizontal.decrease.circle")
                }

                Divider()

                ForEach(RuleCategory.allCases) { category in
                    Button {
                        categoryFilter = categoryFilter == category ? nil : category
                    } label: {
                        Label(category.displayName, systemImage: category.systemImage)
                    }
                }
            } label: {
                Image(systemName: categoryFilter != nil
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
            .menuIndicator(.hidden)
            .help(categoryFilter.map { "Filtering: \($0.displayName)" } ?? "Filter by category")

            // Bulk actions (when multiple rules selected)
            if selectedRuleIds.count > 1 {
                bulkActionsMenu
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Bulk Actions

    /// Extract only rule UUIDs from the multi-selection
    private var selectedRuleIds: Set<UUID> {
        Set(selectedItems.compactMap { item in
            if case let .rule(id) = item { return id }
            return nil
        })
    }

    private var bulkActionsMenu: some View {
        let ids = selectedRuleIds

        return Menu {
            Button {
                appState.tunnelConfig.enableRules(ids)
            } label: {
                Label("Enable", systemImage: "eye")
            }
            Button {
                appState.tunnelConfig.disableRules(ids)
            } label: {
                Label("Disable", systemImage: "eye.slash")
            }

            Divider()

            Menu("Set Outbound") {
                ForEach(RuleOutbound.allCases) { outbound in
                    Button {
                        appState.tunnelConfig.setOutbound(outbound, for: ids)
                    } label: {
                        Label(outbound.displayName, systemImage: outbound.systemImage)
                    }
                }
            }

            Menu("Move to Group") {
                Button("Ungrouped") {
                    appState.tunnelConfig.moveRulesToGroup(nil, ids: ids)
                }
                if !appState.tunnelConfig.groups.isEmpty {
                    Divider()
                    ForEach(appState.tunnelConfig.sortedGroups) { group in
                        Button {
                            appState.tunnelConfig.moveRulesToGroup(group.id, ids: ids)
                        } label: {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                }
            }

            Divider()

            Button("Delete \(ids.count) Rules", role: .destructive) {
                appState.tunnelConfig.rules.removeAll { ids.contains($0.id) }
                selectedItems.removeAll()
                selection = nil
            }
        } label: {
            Label("\(ids.count) selected", systemImage: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List(selection: $selectedItems) {
            // Grouped rules — each group as a header + its rules
            ForEach(appState.tunnelConfig.sortedGroups) { group in
                let groupRules = filteredRules(in: group.id)

                // Hide group header when filtering and no rules match
                if !groupRules.isEmpty || !isFiltering {
                    GroupHeaderRow(
                        group: group,
                        ruleCount: appState.tunnelConfig.rules(in: group.id).count,
                        isEnabled: appState.tunnelConfig.allRulesEnabled(in: group.id),
                        onToggleEnabled: {
                            let enabled = appState.tunnelConfig.allRulesEnabled(in: group.id)
                            appState.tunnelConfig.setGroupEnabled(group.id, enabled: !enabled)
                        },
                        onSetOutbound: { outbound in
                            appState.tunnelConfig.setGroupOutbound(group.id, outbound: outbound)
                        },
                        onToggleExpanded: { appState.tunnelConfig.toggleGroupExpanded(group.id) },
                        onDelete: {
                            if case .group(group.id) = selection { selection = nil }
                            appState.tunnelConfig.deleteGroup(group.id)
                        }
                    )
                    .tag(RuleListSelection.group(group.id))

                    if group.isExpanded {
                        ForEach(groupRules, id: \.id) { rule in
                            ruleRow(rule)
                                .padding(.leading, 20)
                                .tag(RuleListSelection.rule(rule.id))
                        }
                    }
                }
            }

            // Ungrouped rules at the bottom
            let ungrouped = filteredUngroupedRules
            if !ungrouped.isEmpty {
                ForEach(ungrouped, id: \.id) { rule in
                    ruleRow(rule)
                        .tag(RuleListSelection.rule(rule.id))
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: selectedItems) { _, newValue in
            // Sync single selection from multi-selection
            if newValue.count == 1, let item = newValue.first {
                selection = item
            } else if newValue.isEmpty {
                selection = nil
            }
        }
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: RoutingRule) -> some View {
        RuleRow(
            rule: rule,
            onToggleEnabled: { toggleRuleEnabled(rule.id) },
            onDelete: { deleteRule(rule) },
            onSetOutbound: { outbound in setOutbound(outbound, for: rule.id) }
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 4) {
            // Add button
            Menu {
                ForEach(RuleCategory.allCases) { category in
                    Button {
                        activeSheet = .ruleBuilder(category: category)
                    } label: {
                        Label(category.displayName, systemImage: category.systemImage)
                    }
                }

                Divider()

                Button {
                    createGroup()
                } label: {
                    Label("New Group", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .help("Add Rule or Group")

            // Remove button
            Button {
                deleteSelection()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedItems.isEmpty && selection == nil)
            .help("Remove Selected")

            Spacer()

            // Status
            let enabledCount = appState.tunnelConfig.rules.filter(\.isEnabled).count
            let totalCount = appState.tunnelConfig.rules.count
            Text("\(totalCount) rule\(totalCount == 1 ? "" : "s") (\(enabledCount) on)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    // MARK: - Filtering

    private var isFiltering: Bool {
        !searchText.isEmpty || categoryFilter != nil
    }

    private func matchesFilter(_ rule: RoutingRule) -> Bool {
        let matchesSearch = searchText.isEmpty ||
            rule.value.localizedCaseInsensitiveContains(searchText) ||
            rule.type.displayName.localizedCaseInsensitiveContains(searchText) ||
            (rule.note?.localizedCaseInsensitiveContains(searchText) ?? false)

        let matchesCategory = categoryFilter == nil || rule.type.category == categoryFilter

        return matchesSearch && matchesCategory
    }

    private func filteredRules(in groupId: UUID) -> [RoutingRule] {
        appState.tunnelConfig.rules(in: groupId).filter { matchesFilter($0) }
    }

    private var filteredUngroupedRules: [RoutingRule] {
        appState.tunnelConfig.ungroupedRules.filter { matchesFilter($0) }
    }

    /// Total visible items for empty state detection
    private var visibleItemCount: Int {
        let groupedCount = appState.tunnelConfig.sortedGroups.reduce(0) { sum, group in
            sum + filteredRules(in: group.id).count
        }
        return groupedCount + filteredUngroupedRules.count
    }

    // MARK: - Actions

    private func deleteRule(_ rule: RoutingRule) {
        appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
        selectedItems.remove(.rule(rule.id))
        if case .rule(rule.id) = selection {
            selection = nil
        }
    }

    private func toggleRuleEnabled(_ id: UUID) {
        if let i = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
            appState.tunnelConfig.rules[i].isEnabled.toggle()
        }
    }

    private func setOutbound(_ outbound: RuleOutbound, for id: UUID) {
        if let i = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
            appState.tunnelConfig.rules[i].outbound = outbound
            appState.tunnelConfig.rules[i].lastModified = Date()
        }
    }

    private func createGroup() {
        let group = RuleGroup(
            name: "New Group",
            position: appState.tunnelConfig.groups.count
        )
        appState.tunnelConfig.groups.append(group)
        selection = .group(group.id)
        selectedItems = [.group(group.id)]
    }

    private func deleteSelection() {
        // Multi-select: delete all selected items
        if selectedItems.count > 1 {
            let ruleIds = Set(selectedItems.compactMap { item -> UUID? in
                if case let .rule(id) = item { return id }
                return nil
            })
            let groupIds = Set(selectedItems.compactMap { item -> UUID? in
                if case let .group(id) = item { return id }
                return nil
            })

            appState.tunnelConfig.rules.removeAll { ruleIds.contains($0.id) }
            for groupId in groupIds {
                appState.tunnelConfig.deleteGroup(groupId)
            }
            selectedItems.removeAll()
            selection = nil
            return
        }

        // Single selection fallback
        switch selection {
        case let .rule(id):
            appState.tunnelConfig.rules.removeAll { $0.id == id }
            selectedItems.remove(.rule(id))
        case let .group(id):
            appState.tunnelConfig.deleteGroup(id)
            selectedItems.remove(.group(id))
        case nil:
            break
        }
        selection = nil
    }
}
