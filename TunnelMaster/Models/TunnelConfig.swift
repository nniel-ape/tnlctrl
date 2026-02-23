//
//  TunnelConfig.swift
//  TunnelMaster
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

    /// Add tag to rules by ID set
    mutating func addTag(_ tag: String, to ids: Set<UUID>) {
        updateRules(where: { ids.contains($0.id) }, mutation: { rule in
            if !rule.tags.contains(tag) {
                rule.tags.append(tag)
            }
        })
    }
}
