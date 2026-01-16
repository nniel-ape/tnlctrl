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

    init(
        mode: TunnelMode = .full,
        selectedServiceId: UUID? = nil,
        chainEnabled: Bool = false,
        chain: [UUID] = [],
        rules: [RoutingRule] = [],
        finalOutbound: RuleOutbound = .direct
    ) {
        self.mode = mode
        self.selectedServiceId = selectedServiceId
        self.chainEnabled = chainEnabled
        self.chain = chain
        self.rules = rules
        self.finalOutbound = finalOutbound
    }

    nonisolated static let `default` = TunnelConfig()

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case mode
        case selectedServiceId
        case chainEnabled
        case chain
        case rules
        case finalOutbound
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        mode = try container.decode(TunnelMode.self, forKey: .mode)
        rules = try container.decodeIfPresent([RoutingRule].self, forKey: .rules) ?? []
        chain = try container.decodeIfPresent([UUID].self, forKey: .chain) ?? []

        // New fields with migration defaults
        selectedServiceId = try container.decodeIfPresent(UUID.self, forKey: .selectedServiceId)
        chainEnabled = try container.decodeIfPresent(Bool.self, forKey: .chainEnabled) ?? !chain.isEmpty
        finalOutbound = try container.decodeIfPresent(RuleOutbound.self, forKey: .finalOutbound)
            ?? (mode == .split ? .direct : .proxy)
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
