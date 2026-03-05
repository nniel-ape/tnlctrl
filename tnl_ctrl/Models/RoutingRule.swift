//
//  RoutingRule.swift
//  tnl_ctrl
//

import Foundation
import SwiftUI

struct RoutingRule: Identifiable, Codable, Hashable {
    let id: UUID
    var type: RuleType
    var value: String
    var outbound: RuleOutbound
    var isEnabled: Bool
    var note: String?
    var groupId: UUID?
    var createdAt: Date
    var lastModified: Date

    init(
        id: UUID = UUID(),
        type: RuleType,
        value: String,
        outbound: RuleOutbound,
        isEnabled: Bool = true,
        note: String? = nil,
        groupId: UUID? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.outbound = outbound
        self.isEnabled = isEnabled
        self.note = note
        self.groupId = groupId
        self.createdAt = createdAt
        self.lastModified = lastModified
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case outbound
        case isEnabled
        case note
        case groupId
        case tags
        case createdAt
        case lastModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(RuleType.self, forKey: .type)
        self.value = try container.decode(String.self, forKey: .value)
        self.outbound = try container.decode(RuleOutbound.self, forKey: .outbound)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()

        // Migration: read & discard old tags field
        _ = try container.decodeIfPresent([String].self, forKey: .tags)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(outbound, forKey: .outbound)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModified, forKey: .lastModified)
        // tags intentionally not encoded — removed feature
    }
}

enum RuleType: String, Codable, CaseIterable, Identifiable {
    // Process-based rules
    case processName = "process_name"
    case processPath = "process_path"

    // Domain rules
    case domain
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"

    /// IP rules
    case ipCidr = "ip_cidr"

    // Geo rules
    case geoip
    case geosite

    var id: String {
        rawValue
    }

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

    var shortName: String {
        switch self {
        case .processName: "App"
        case .processPath: "Path"
        case .domain: "Domain"
        case .domainSuffix: "Suffix"
        case .domainKeyword: "Keyword"
        case .ipCidr: "IP"
        case .geoip: "GeoIP"
        case .geosite: "GeoSite"
        }
    }
}

enum RuleCategory: String, CaseIterable, Identifiable {
    case app
    case domain
    case ip
    case geoSite
    case geoIP

    var id: String {
        rawValue
    }

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

enum RuleOutbound: String, Codable, CaseIterable, Identifiable {
    case direct
    case proxy
    case block

    var id: String {
        rawValue
    }

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

    var color: Color {
        switch self {
        case .direct: .green
        case .proxy: .blue
        case .block: .red
        }
    }
}
