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

    init(
        id: UUID = UUID(),
        type: RuleType,
        value: String,
        outbound: RuleOutbound
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.outbound = outbound
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
