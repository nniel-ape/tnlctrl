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
    var customPresets: [RulePreset]

    init(
        mode: TunnelMode = .full,
        selectedServiceId: UUID? = nil,
        chainEnabled: Bool = false,
        chain: [UUID] = [],
        rules: [RoutingRule] = [],
        finalOutbound: RuleOutbound = .direct,
        customPresets: [RulePreset] = []
    ) {
        self.mode = mode
        self.selectedServiceId = selectedServiceId
        self.chainEnabled = chainEnabled
        self.chain = chain
        self.rules = rules
        self.finalOutbound = finalOutbound
        self.customPresets = customPresets
    }

    nonisolated static let `default` = TunnelConfig()

    /// All presets (built-in + custom)
    var allPresets: [RulePreset] {
        RulePreset.builtInPresets + customPresets
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case mode
        case selectedServiceId
        case chainEnabled
        case chain
        case rules
        case finalOutbound
        case customPresets
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
        self.customPresets = try container.decodeIfPresent([RulePreset].self, forKey: .customPresets) ?? []
    }
}

enum TunnelMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case full
    case split

    var id: String { rawValue }

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
