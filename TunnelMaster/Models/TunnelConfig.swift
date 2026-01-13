//
//  TunnelConfig.swift
//  TunnelMaster
//

import Foundation

struct TunnelConfig: Codable, Hashable {
    var mode: TunnelMode
    var rules: [RoutingRule]
    var chain: [UUID]

    init(
        mode: TunnelMode = .full,
        rules: [RoutingRule] = [],
        chain: [UUID] = []
    ) {
        self.mode = mode
        self.rules = rules
        self.chain = chain
    }

    static let `default` = TunnelConfig()
}

enum TunnelMode: String, Codable, CaseIterable, Identifiable {
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
        case .full: "Route all traffic through the tunnel"
        case .split: "Route only matching traffic through the tunnel"
        }
    }
}
