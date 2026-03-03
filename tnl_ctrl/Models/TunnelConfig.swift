//
//  TunnelConfig.swift
//  tnl_ctrl
//

import Foundation

struct TunnelConfig: Codable, Hashable, Sendable {
    var mode: TunnelMode
    var selectedServiceId: UUID?
    var chainEnabled: Bool
    var chain: [UUID]
    var rules: [RoutingRule]
    var finalOutbound: RuleOutbound
    /// Rule groups for organization
    var groups: [RuleGroup]

    init(
        mode: TunnelMode = .full,
        selectedServiceId: UUID? = nil,
        chainEnabled: Bool = false,
        chain: [UUID] = [],
        rules: [RoutingRule] = [],
        finalOutbound: RuleOutbound = .direct,
        groups: [RuleGroup] = []
    ) {
        self.mode = mode
        self.selectedServiceId = selectedServiceId
        self.chainEnabled = chainEnabled
        self.chain = chain
        self.rules = rules
        self.finalOutbound = finalOutbound
        self.groups = groups
    }

    nonisolated static let `default` = TunnelConfig()

    // MARK: - Helper Methods

    /// Get rules that are not in any group
    var ungroupedRules: [RoutingRule] {
        rules.filter { $0.groupId == nil }
    }

    /// Get rules belonging to a specific group
    func rules(in groupId: UUID) -> [RoutingRule] {
        rules.filter { $0.groupId == groupId }
    }

    /// Get rules for a specific category
    func rules(for category: RuleCategory) -> [RoutingRule] {
        rules.filter { $0.type.category == category }
    }

    /// Get sorted groups by position
    var sortedGroups: [RuleGroup] {
        groups.sorted { $0.position < $1.position }
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case mode
        case selectedServiceId
        case chainEnabled
        case chain
        case rules
        case finalOutbound
        case groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.mode = try container.decode(TunnelMode.self, forKey: .mode)
        self.rules = try container.decodeIfPresent([RoutingRule].self, forKey: .rules) ?? []
        self.chain = try container.decodeIfPresent([UUID].self, forKey: .chain) ?? []

        // New fields with migration defaults
        self.selectedServiceId = try container.decodeIfPresent(UUID.self, forKey: .selectedServiceId)
        self.chainEnabled = try container.decodeIfPresent(Bool.self, forKey: .chainEnabled) ?? !chain.isEmpty
        self.finalOutbound = try container.decodeIfPresent(RuleOutbound.self, forKey: .finalOutbound)
            ?? (mode == .split ? .direct : .proxy)

        // Defaults to empty array for migration from older configs
        self.groups = try container.decodeIfPresent([RuleGroup].self, forKey: .groups) ?? []
    }
}

enum TunnelMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case full
    case split

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .full: "Full Tunnel"
        case .split: "Split Tunnel"
        }
    }

    var description: String {
        switch self {
        case .full: "Route all traffic through the proxy"
        case .split: "Only matching traffic goes through proxy"
        }
    }

    var icon: String {
        switch self {
        case .full: "globe"
        case .split: "arrow.triangle.branch"
        }
    }
}

// MARK: - Bulk Operation Helpers

extension TunnelConfig {
    /// Apply a mutation to rules matching predicate
    mutating func updateRules(
        where predicate: (RoutingRule) -> Bool,
        mutation: (inout RoutingRule) -> Void
    ) {
        for i in 0 ..< rules.count where predicate(rules[i]) {
            mutation(&rules[i])
            rules[i].lastModified = Date()
        }
    }

    /// Enable rules by ID set
    mutating func enableRules(_ ids: Set<UUID>) {
        updateRules(where: { ids.contains($0.id) }, mutation: { $0.isEnabled = true })
    }

    /// Disable rules by ID set
    mutating func disableRules(_ ids: Set<UUID>) {
        updateRules(where: { ids.contains($0.id) }, mutation: { $0.isEnabled = false })
    }

    /// Change outbound for rules by ID set
    mutating func setOutbound(_ outbound: RuleOutbound, for ids: Set<UUID>) {
        updateRules(where: { ids.contains($0.id) }, mutation: { $0.outbound = outbound })
    }

    /// Move rules to group by ID set
    mutating func moveRulesToGroup(_ groupId: UUID?, ids: Set<UUID>) {
        updateRules(where: { ids.contains($0.id) }, mutation: { $0.groupId = groupId })
    }

    /// Whether all rules in a group are enabled
    func allRulesEnabled(in groupId: UUID) -> Bool {
        let groupRules = rules(in: groupId)
        return !groupRules.isEmpty && groupRules.allSatisfy(\.isEnabled)
    }

    /// Set outbound for all rules in a group
    mutating func setGroupOutbound(_ groupId: UUID, outbound: RuleOutbound) {
        let ids = Set(rules(in: groupId).map(\.id))
        setOutbound(outbound, for: ids)
    }

    /// Enable or disable all rules in a group
    mutating func setGroupEnabled(_ groupId: UUID, enabled: Bool) {
        let ids = Set(rules(in: groupId).map(\.id))
        if enabled {
            enableRules(ids)
        } else {
            disableRules(ids)
        }
    }

    /// Toggle a group's expanded state
    mutating func toggleGroupExpanded(_ groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].isExpanded.toggle()
        }
    }

    /// Delete a group, ungrouping its rules first
    mutating func deleteGroup(_ groupId: UUID) {
        for i in 0 ..< rules.count where rules[i].groupId == groupId {
            rules[i].groupId = nil
        }
        groups.removeAll { $0.id == groupId }
    }
}

// MARK: - Drag & Drop Reordering

extension TunnelConfig {
    /// Move a single rule to a target group at a specific index within that group's rules.
    /// `targetGroupId` of nil means ungrouped. `atGroupIndex` is the position within the group's rules.
    mutating func moveRule(_ ruleId: UUID, toGroup targetGroupId: UUID?, atGroupIndex: Int) {
        guard let sourceIndex = rules.firstIndex(where: { $0.id == ruleId }) else { return }

        var rule = rules.remove(at: sourceIndex)
        rule.groupId = targetGroupId

        let flatIndex = flatInsertionIndex(forGroup: targetGroupId, atGroupIndex: atGroupIndex)
        rules.insert(rule, at: flatIndex)
    }

    /// Move multiple rules to a target group at a specific index within that group's rules.
    mutating func moveRules(_ ruleIds: [UUID], toGroup targetGroupId: UUID?, atGroupIndex: Int) {
        let idSet = Set(ruleIds)
        // Extract in array order to preserve relative ordering
        let movingRules = rules.filter { idSet.contains($0.id) }
        rules.removeAll { idSet.contains($0.id) }

        let flatIndex = flatInsertionIndex(forGroup: targetGroupId, atGroupIndex: atGroupIndex)
        for (offset, var rule) in movingRules.enumerated() {
            rule.groupId = targetGroupId
            rules.insert(rule, at: min(flatIndex + offset, rules.count))
        }
    }

    /// Reorder a group to a new position among groups.
    mutating func moveGroup(_ groupId: UUID, toPosition newPosition: Int) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        let group = groups.remove(at: index)
        let clamped = min(max(newPosition, 0), groups.count)
        groups.insert(group, at: clamped)
        renormalizeGroupPositions()
    }

    // MARK: - Private Helpers

    /// Map a group-local index to a flat-array insertion index.
    private func flatInsertionIndex(forGroup groupId: UUID?, atGroupIndex: Int) -> Int {
        let groupRules: [RoutingRule] = if let groupId {
            rules.filter { $0.groupId == groupId }
        } else {
            rules.filter { $0.groupId == nil }
        }

        if atGroupIndex >= groupRules.count {
            // Append after last rule in this group
            if let lastRule = groupRules.last, let lastIdx = rules.firstIndex(where: { $0.id == lastRule.id }) {
                return lastIdx + 1
            }
            // Empty group — find where this group's rules should go based on group ordering
            return insertionPointForEmptyGroup(groupId)
        }

        // Insert before the rule at atGroupIndex
        let targetRule = groupRules[atGroupIndex]
        return rules.firstIndex(where: { $0.id == targetRule.id }) ?? rules.count
    }

    /// For an empty group, determine the flat-array index where its rules should be inserted.
    private func insertionPointForEmptyGroup(_ groupId: UUID?) -> Int {
        guard let groupId else {
            // Ungrouped goes at end
            return rules.count
        }

        let sorted = sortedGroups
        guard let groupPosition = sorted.firstIndex(where: { $0.id == groupId }) else {
            return rules.count
        }

        // Look for the first rule belonging to a subsequent group
        for laterGroup in sorted[(groupPosition + 1)...] {
            if let firstRule = rules.first(where: { $0.groupId == laterGroup.id }),
               let idx = rules.firstIndex(where: { $0.id == firstRule.id }) {
                return idx
            }
        }

        // No subsequent group has rules — insert before ungrouped rules
        if let firstUngrouped = rules.firstIndex(where: { $0.groupId == nil }) {
            return firstUngrouped
        }

        return rules.count
    }

    /// Renormalize group positions to 0, 1, 2, ...
    private mutating func renormalizeGroupPositions() {
        for i in 0 ..< groups.count {
            groups[i].position = i
        }
    }
}
