//
//  RuleListView.swift
//  TunnelMaster
//
//  Flat rule list panel with bottom toolbar and status bar.
//

import SwiftUI

struct RuleListView: View {
    @Environment(AppState.self) private var appState

    @Binding var selectedRuleId: UUID?
    @Binding var selectedRuleIds: Set<UUID>

    @State private var searchText = ""
    @State private var categoryFilter: RuleCategory?
    @State private var activeSheet: SheetDestination?

    enum SheetDestination: Identifiable {
        case groupManager
        case ruleBuilder(category: RuleCategory)

        var id: String {
            switch self {
            case .groupManager: "groupManager"
            case let .ruleBuilder(cat): "ruleBuilder-\(cat.rawValue)"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if filteredRules.isEmpty, searchText.isEmpty, categoryFilter == nil {
                ContentUnavailableView(
                    "No Rules",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Add rules to control routing")
                )
            } else if filteredRules.isEmpty {
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
            case .groupManager:
                GroupManagerSheet()
            case let .ruleBuilder(category):
                RuleBuilderSheet(category: category) { newRuleId in
                    selectedRuleId = newRuleId
                    selectedRuleIds = [newRuleId]
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

            // Bulk actions (when multi-selected)
            if selectedRuleIds.count > 1 {
                bulkActionsMenu
            }

            Spacer()

            // Group manager
            Button {
                activeSheet = .groupManager
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .help("Manage Groups")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

            Button("Delete \(selectedRuleIds.count) Rules", role: .destructive) {
                appState.tunnelConfig.rules.removeAll { selectedRuleIds.contains($0.id) }
                selectedRuleIds.removeAll()
                selectedRuleId = nil
            }
        } label: {
            Label("\(selectedRuleIds.count) selected", systemImage: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List(selection: $selectedRuleIds) {
            ForEach(filteredRules, id: \.id) { rule in
                ruleRow(rule)
                    .tag(rule.id)
            }
            .onMove { source, destination in
                appState.tunnelConfig.rules.move(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: selectedRuleIds) { _, newValue in
            // Sync single selection from multi-selection
            if newValue.count == 1, let id = newValue.first {
                selectedRuleId = id
            } else if newValue.isEmpty {
                selectedRuleId = nil
            }
        }
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: RoutingRule) -> some View {
        let group = rule.groupId.flatMap { gid in
            appState.tunnelConfig.groups.first(where: { $0.id == gid })
        }

        return RuleRow(
            rule: rule,
            group: group,
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
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .help("Add Rule")

            // Remove button
            Button {
                if let id = selectedRuleId {
                    appState.tunnelConfig.rules.removeAll { $0.id == id }
                    selectedRuleIds.remove(id)
                    selectedRuleId = nil
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedRuleId == nil)
            .help("Remove Selected Rule")

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

    private var filteredRules: [RoutingRule] {
        appState.tunnelConfig.rules.filter { rule in
            let matchesSearch = searchText.isEmpty ||
                rule.value.localizedCaseInsensitiveContains(searchText) ||
                rule.type.displayName.localizedCaseInsensitiveContains(searchText) ||
                (rule.note?.localizedCaseInsensitiveContains(searchText) ?? false)

            let matchesCategory = categoryFilter == nil || rule.type.category == categoryFilter

            return matchesSearch && matchesCategory
        }
    }

    // MARK: - Actions

    private func deleteRule(_ rule: RoutingRule) {
        appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
        selectedRuleIds.remove(rule.id)
        if selectedRuleId == rule.id {
            selectedRuleId = nil
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
}
