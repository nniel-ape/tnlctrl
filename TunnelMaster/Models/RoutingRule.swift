//
//  RoutingRule.swift
//  TunnelMaster
//

import Foundation

struct RoutingRule: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: RuleType
    var value: String
    var outbound: RuleOutbound
    var isEnabled: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        type: RuleType,
        value: String,
        outbound: RuleOutbound,
        isEnabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.outbound = outbound
        self.isEnabled = isEnabled
        self.note = note
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case outbound
        case isEnabled
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(RuleType.self, forKey: .type)
        self.value = try container.decode(String.self, forKey: .value)
        self.outbound = try container.decode(RuleOutbound.self, forKey: .outbound)
        // Migration: default to enabled for existing rules
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

enum RuleType: String, Codable, CaseIterable, Identifiable, Sendable {
    // Process-based rules
    case processName = "process_name"
    case processPath = "process_path"

    // Domain rules
    case domain
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"

    // IP rules
    case ipCidr = "ip_cidr"

    // Geo rules
    case geoip
    case geosite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .processName: "Process Name"
        case .processPath: "Process Path"
        case .domain: "Domain"
        case .domainSuffix: "Domain Suffix"
        case .domainKeyword: "Domain Keyword"
        case .ipCidr: "IP CIDR"
        case .geoip: "GeoIP"
        case .geosite: "GeoSite"
        }
    }

    var placeholder: String {
        switch self {
        case .processName: "Safari"
        case .processPath: "/Applications/Safari.app"
        case .domain: "example.com"
        case .domainSuffix: "google.com"
        case .domainKeyword: "facebook"
        case .ipCidr: "192.168.0.0/16"
        case .geoip: "US"
        case .geosite: "google"
        }
    }

    var singBoxKey: String {
        rawValue
    }

    var category: RuleCategory {
        switch self {
        case .processName, .processPath:
            return .app
        case .domain, .domainSuffix, .domainKeyword:
            return .domain
        case .ipCidr:
            return .ip
        case .geoip:
            return .geoIP
        case .geosite:
            return .geoSite
        }
    }

    var systemImage: String {
        switch self {
        case .processName, .processPath:
            return "app.badge"
        case .domain, .domainSuffix, .domainKeyword:
            return "globe"
        case .ipCidr:
            return "number"
        case .geoip:
            return "flag"
        case .geosite:
            return "list.bullet.rectangle"
        }
    }
}

enum RuleCategory: String, CaseIterable, Identifiable, Sendable {
    case app
    case domain
    case ip
    case geoSite
    case geoIP

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: "App"
        case .domain: "Domain"
        case .ip: "IP Range"
        case .geoSite: "GeoSite"
        case .geoIP: "GeoIP"
        }
    }

    var description: String {
        switch self {
        case .app: "Route traffic from specific applications"
        case .domain: "Route traffic to specific domains"
        case .ip: "Route traffic to IP address ranges"
        case .geoSite: "Route traffic by site category"
        case .geoIP: "Route traffic by country"
        }
    }

    var systemImage: String {
        switch self {
        case .app: "app.badge"
        case .domain: "globe"
        case .ip: "number"
        case .geoSite: "list.bullet.rectangle"
        case .geoIP: "flag"
        }
    }

    var ruleTypes: [RuleType] {
        switch self {
        case .app: [.processName, .processPath]
        case .domain: [.domain, .domainSuffix, .domainKeyword]
        case .ip: [.ipCidr]
        case .geoSite: [.geosite]
        case .geoIP: [.geoip]
        }
    }
}

enum RuleOutbound: String, Codable, CaseIterable, Identifiable, Sendable {
    case direct
    case proxy
    case block

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .direct: "Direct"
        case .proxy: "Proxy"
        case .block: "Block"
        }
    }

    var systemImage: String {
        switch self {
        case .direct: "arrow.right"
        case .proxy: "arrow.triangle.turn.up.right.diamond"
        case .block: "xmark.octagon"
        }
    }
}
