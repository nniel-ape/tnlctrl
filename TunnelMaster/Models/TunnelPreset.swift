//
//  TunnelPreset.swift
//  TunnelMaster
//

import Foundation

struct TunnelPreset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var mode: TunnelMode
    var finalOutbound: RuleOutbound
    var selectedServiceId: UUID?
    var chainEnabled: Bool
    var chain: [UUID]
    var enabledRuleIds: Set<UUID>
    var createdAt: Date

    /// Update this preset's config fields from the given tunnel config, preserving id/name/createdAt.
    mutating func updateFromConfig(_ config: TunnelConfig) {
        mode = config.mode
        finalOutbound = config.finalOutbound
        selectedServiceId = config.selectedServiceId
        chainEnabled = config.chainEnabled
        chain = config.chain
        enabledRuleIds = Set(config.rules.filter(\.isEnabled).map(\.id))
    }

    /// Snapshot the current tunnel config into a new preset
    init(name: String, config: TunnelConfig) {
        self.id = UUID()
        self.name = name
        self.mode = config.mode
        self.finalOutbound = config.finalOutbound
        self.selectedServiceId = config.selectedServiceId
        self.chainEnabled = config.chainEnabled
        self.chain = config.chain
        self.enabledRuleIds = Set(config.rules.filter(\.isEnabled).map(\.id))
        self.createdAt = Date()
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mode
        case finalOutbound
        case selectedServiceId
        case chainEnabled
        case chain
        case enabledRuleIds
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.mode = try container.decode(TunnelMode.self, forKey: .mode)
        self.finalOutbound = try container.decode(RuleOutbound.self, forKey: .finalOutbound)
        self.selectedServiceId = try container.decodeIfPresent(UUID.self, forKey: .selectedServiceId)
        self.chainEnabled = try container.decodeIfPresent(Bool.self, forKey: .chainEnabled) ?? false
        self.chain = try container.decodeIfPresent([UUID].self, forKey: .chain) ?? []
        self.enabledRuleIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .enabledRuleIds) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
