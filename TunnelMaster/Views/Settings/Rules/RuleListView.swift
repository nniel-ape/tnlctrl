//
//  RuleListView.swift
//  TunnelMaster
//
//  Grouped rule list with inline group headers, bottom toolbar, and status bar.
//

import SwiftUI
import UniformTypeIdentifiers

struct RuleListView: View {
    @Environment(AppState.self) private var appState

    @Binding var selection: RuleListSelection?
    @Binding var selectedItems: Set<RuleListSelection>

    @State private var searchText = ""
    @State private var categoryFilter: RuleCategory?
    @State private var activeSheet: SheetDestination?
    @State private var draggedRuleId: UUID?
    @State private var draggedGroupId: UUID?

    // MARK: - Cached Filtered Results

    @State private var cachedSortedGroups: [RuleGroup] = []
    @State private var cachedGroupRules: [UUID: [RoutingRule]] = [:]
    @State private var cachedGroupRuleCounts: [UUID: Int] = [:]
    @State private var cachedGroupAllEnabled: [UUID: Bool] = [:]
    @State private var cachedUngroupedRules: [RoutingRule] = []
    @State private var cachedEnabledCount = 0

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
            } else if cachedVisibleItemCount == 0, !searchText.isEmpty || categoryFilter != nil {
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
        .onAppear { recomputeFilteredRules() }
        .onChange(of: searchText) { _, _ in recomputeFilteredRules() }
        .onChange(of: categoryFilter) { _, _ in recomputeFilteredRules() }
        .onChange(of: appState.tunnelConfig.rules) { _, _ in recomputeFilteredRules() }
        .onChange(of: appState.tunnelConfig.groups) { _, _ in recomputeFilteredRules() }
    }

    // MARK: - Cache Recomputation

    private func recomputeFilteredRules() {
        let sorted = appState.tunnelConfig.groups.sorted { $0.position < $1.position }
        cachedSortedGroups = sorted

        var groupRules: [UUID: [RoutingRule]] = [:]
        var groupCounts: [UUID: Int] = [:]
        var groupEnabled: [UUID: Bool] = [:]

        for group in sorted {
            let allInGroup = appState.tunnelConfig.rules.filter { $0.groupId == group.id }
            let filtered = allInGroup.filter { matchesFilter($0) }
            groupRules[group.id] = filtered
            groupCounts[group.id] = allInGroup.count
            groupEnabled[group.id] = !allInGroup.isEmpty && allInGroup.allSatisfy(\.isEnabled)
        }

        cachedGroupRules = groupRules
        cachedGroupRuleCounts = groupCounts
        cachedGroupAllEnabled = groupEnabled
        cachedUngroupedRules = appState.tunnelConfig.rules
            .filter { $0.groupId == nil }
            .filter { matchesFilter($0) }
        cachedEnabledCount = appState.tunnelConfig.rules.filter(\.isEnabled).count
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
                if !cachedSortedGroups.isEmpty {
                    Divider()
                    ForEach(cachedSortedGroups) { group in
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

    /// Whether drag-and-drop is enabled (disabled while filtering since visible order != actual order)
    private var isDragEnabled: Bool {
        !isFiltering
    }

    private var rulesList: some View {
        List(selection: $selectedItems) {
            // Grouped rules — each group as a header + its rules
            ForEach(cachedSortedGroups) { group in
                let groupRules = cachedGroupRules[group.id] ?? []

                // Hide group header when filtering and no rules match
                if !groupRules.isEmpty || !isFiltering {
                    groupHeaderWithDrag(group)

                    if group.isExpanded {
                        ForEach(groupRules, id: \.id) { rule in
                            ruleRowWithDrag(rule)
                                .padding(.leading, 20)
                                .tag(RuleListSelection.rule(rule.id))
                        }
                        .onInsert(of: [.ruleDragItem]) { index, _ in
                            guard isDragEnabled else { return }
                            handleInsert(at: index, inGroup: group.id)
                        }
                    }
                }
            }

            // Ungrouped rules (always present so .onInsert provides a drop target)
            ForEach(cachedUngroupedRules, id: \.id) { rule in
                ruleRowWithDrag(rule)
                    .tag(RuleListSelection.rule(rule.id))
            }
            .onInsert(of: [.ruleDragItem]) { index, _ in
                guard isDragEnabled else { return }
                handleInsert(at: index, inGroup: nil)
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

    // MARK: - Drag & Drop

    /// Group header with drag (for reordering groups) and drop (for rules dropped onto the group)
    @ViewBuilder
    private func groupHeaderWithDrag(_ group: RuleGroup) -> some View {
        let header = GroupHeaderRow(
            group: group,
            ruleCount: cachedGroupRuleCounts[group.id] ?? 0,
            isEnabled: cachedGroupAllEnabled[group.id] ?? false,
            onToggleEnabled: {
                let enabled = cachedGroupAllEnabled[group.id] ?? false
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

        if isDragEnabled {
            header
                .onDrag {
                    draggedGroupId = group.id
                    return makeDragProvider(.group(group.id))
                } preview: {
                    dragPreview(for: .group(group.id))
                }
                .dropDestination(for: RuleDragItem.self) { items, _ in
                    handleDropOnGroupHeader(items, groupId: group.id)
                }
        } else {
            header
        }
    }

    /// Rule row with .onDrag for initiating drags (insertion handled by .onInsert on ForEach)
    @ViewBuilder
    private func ruleRowWithDrag(_ rule: RoutingRule) -> some View {
        let row = ruleRow(rule)
        if isDragEnabled {
            row.onDrag {
                draggedRuleId = rule.id
                return makeDragProvider(.rule(rule.id))
            } preview: {
                dragPreview(for: .rule(rule.id))
            }
        } else {
            row
        }
    }

    /// Create an NSItemProvider with encoded RuleDragItem data
    private func makeDragProvider(_ item: RuleDragItem) -> NSItemProvider {
        let provider = NSItemProvider()
        if let data = try? JSONEncoder().encode(item) {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.ruleDragItem.identifier,
                visibility: .ownProcess
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        return provider
    }

    /// Custom drag preview
    @ViewBuilder
    private func dragPreview(for item: RuleDragItem) -> some View {
        switch item {
        case let .rule(id):
            let count = ruleIdsForDrag(id).count
            if count > 1 {
                Label("\(count) rules", systemImage: "list.bullet")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            } else if let rule = appState.tunnelConfig.rules.first(where: { $0.id == id }) {
                Text(rule.value)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
        case let .group(id):
            if let group = appState.tunnelConfig.groups.first(where: { $0.id == id }) {
                Label(group.name, systemImage: group.icon)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Drop Handlers

    /// Returns the rule IDs to move when dragging a rule (supports multi-selection)
    private func ruleIdsForDrag(_ draggedRuleId: UUID) -> [UUID] {
        if selectedRuleIds.contains(draggedRuleId), selectedRuleIds.count > 1 {
            // Move all selected rules, preserving their array order
            return appState.tunnelConfig.rules
                .filter { selectedRuleIds.contains($0.id) }
                .map(\.id)
        }
        return [draggedRuleId]
    }

    /// Handle .onInsert — rule dragged between rows (produces native blue insertion line)
    private func handleInsert(at index: Int, inGroup groupId: UUID?) {
        if let ruleId = draggedRuleId {
            let ids = ruleIdsForDrag(ruleId)
            appState.tunnelConfig.moveRules(ids, toGroup: groupId, atGroupIndex: index)
            draggedRuleId = nil
        } else if let groupId2 = draggedGroupId, groupId == nil {
            // Group dragged to ungrouped area → move group to end
            appState.tunnelConfig.moveGroup(groupId2, toPosition: appState.tunnelConfig.groups.count)
            draggedGroupId = nil
        }
    }

    /// Drop rule(s) onto a group header — appends to the group
    @discardableResult
    private func handleDropOnGroupHeader(_ items: [RuleDragItem], groupId: UUID) -> Bool {
        guard let item = items.first else { return false }
        switch item {
        case let .rule(ruleId):
            let ids = ruleIdsForDrag(ruleId)
            let endIndex = appState.tunnelConfig.rules(in: groupId).count
            appState.tunnelConfig.moveRules(ids, toGroup: groupId, atGroupIndex: endIndex)
            // Auto-expand the group when dropping into it
            if let gi = appState.tunnelConfig.groups.firstIndex(where: { $0.id == groupId }),
               !appState.tunnelConfig.groups[gi].isExpanded {
                appState.tunnelConfig.groups[gi].isExpanded = true
            }
            return true
        case let .group(draggedGroupId):
            guard draggedGroupId != groupId else { return false }
            if let targetIdx = appState.tunnelConfig.sortedGroups.firstIndex(where: { $0.id == groupId }) {
                appState.tunnelConfig.moveGroup(draggedGroupId, toPosition: targetIdx)
            }
            return true
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
            let totalCount = appState.tunnelConfig.rules.count
            Text("\(totalCount) rule\(totalCount == 1 ? "" : "s") (\(cachedEnabledCount) on)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}

// MARK: - Filtering & Actions

extension RuleListView {
    var isFiltering: Bool {
        !searchText.isEmpty || categoryFilter != nil
    }

    func matchesFilter(_ rule: RoutingRule) -> Bool {
        let matchesSearch = searchText.isEmpty ||
            rule.value.localizedCaseInsensitiveContains(searchText) ||
            rule.type.displayName.localizedCaseInsensitiveContains(searchText) ||
            (rule.note?.localizedCaseInsensitiveContains(searchText) ?? false)

        let matchesCategory = categoryFilter == nil || rule.type.category == categoryFilter

        return matchesSearch && matchesCategory
    }

    func filteredRules(in groupId: UUID) -> [RoutingRule] {
        appState.tunnelConfig.rules(in: groupId).filter { matchesFilter($0) }
    }

    var filteredUngroupedRules: [RoutingRule] {
        appState.tunnelConfig.ungroupedRules.filter { matchesFilter($0) }
    }

    /// Total visible items for empty state detection (uses cached values)
    var cachedVisibleItemCount: Int {
        let groupedCount = cachedGroupRules.values.reduce(0) { $0 + $1.count }
        return groupedCount + cachedUngroupedRules.count
    }

    func deleteRule(_ rule: RoutingRule) {
        appState.tunnelConfig.rules.removeAll { $0.id == rule.id }
        selectedItems.remove(.rule(rule.id))
        if case .rule(rule.id) = selection {
            selection = nil
        }
    }

    func toggleRuleEnabled(_ id: UUID) {
        if let i = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
            appState.tunnelConfig.rules[i].isEnabled.toggle()
        }
    }

    func setOutbound(_ outbound: RuleOutbound, for id: UUID) {
        if let i = appState.tunnelConfig.rules.firstIndex(where: { $0.id == id }) {
            appState.tunnelConfig.rules[i].outbound = outbound
            appState.tunnelConfig.rules[i].lastModified = Date()
        }
    }

    func createGroup() {
        let group = RuleGroup(
            name: "New Group",
            position: appState.tunnelConfig.groups.count
        )
        appState.tunnelConfig.groups.append(group)
        selection = .group(group.id)
        selectedItems = [.group(group.id)]
    }

    func deleteSelection() {
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
