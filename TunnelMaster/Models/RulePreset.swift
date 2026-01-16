//
//  RulePreset.swift
//  TunnelMaster
//

import Foundation

struct RulePreset: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let rules: [RoutingRule]
    let isBuiltIn: Bool

    init(
        id: String,
        name: String,
        description: String,
        rules: [RoutingRule],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.rules = rules
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Built-in Presets

extension RulePreset {
    static let builtInPresets: [RulePreset] = [
        .chinaDirect,
        .streaming,
        .blockAds,
        .socialMedia,
        .privateDirect
    ]

    /// Route China traffic directly (bypass proxy)
    static let chinaDirect = RulePreset(
        id: "china-direct",
        name: "China Direct",
        description: "Route traffic to China directly",
        rules: [
            RoutingRule(type: .geoip, value: "cn", outbound: .direct),
            RoutingRule(type: .geosite, value: "cn", outbound: .direct)
        ],
        isBuiltIn: true
    )

    /// Route streaming services through proxy
    static let streaming = RulePreset(
        id: "streaming",
        name: "Streaming",
        description: "Route Netflix, YouTube, etc. through proxy",
        rules: [
            RoutingRule(type: .geosite, value: "netflix", outbound: .proxy),
            RoutingRule(type: .geosite, value: "youtube", outbound: .proxy),
            RoutingRule(type: .geosite, value: "disney", outbound: .proxy),
            RoutingRule(type: .geosite, value: "hbo", outbound: .proxy),
            RoutingRule(type: .geosite, value: "spotify", outbound: .proxy),
            RoutingRule(type: .domainSuffix, value: "twitch.tv", outbound: .proxy)
        ],
        isBuiltIn: true
    )

    /// Block advertisement domains
    static let blockAds = RulePreset(
        id: "block-ads",
        name: "Block Ads",
        description: "Block common advertisement domains",
        rules: [
            RoutingRule(type: .geosite, value: "category-ads", outbound: .block),
            RoutingRule(type: .geosite, value: "category-ads-all", outbound: .block)
        ],
        isBuiltIn: true
    )

    /// Route social media through proxy
    static let socialMedia = RulePreset(
        id: "social-media",
        name: "Social Media",
        description: "Route social media through proxy",
        rules: [
            RoutingRule(type: .geosite, value: "facebook", outbound: .proxy),
            RoutingRule(type: .geosite, value: "twitter", outbound: .proxy),
            RoutingRule(type: .geosite, value: "instagram", outbound: .proxy),
            RoutingRule(type: .geosite, value: "tiktok", outbound: .proxy),
            RoutingRule(type: .geosite, value: "telegram", outbound: .proxy)
        ],
        isBuiltIn: true
    )

    /// Route private/local networks directly
    static let privateDirect = RulePreset(
        id: "private-direct",
        name: "Private Networks",
        description: "Route local/private IPs directly",
        rules: [
            RoutingRule(type: .ipCidr, value: "10.0.0.0/8", outbound: .direct),
            RoutingRule(type: .ipCidr, value: "172.16.0.0/12", outbound: .direct),
            RoutingRule(type: .ipCidr, value: "192.168.0.0/16", outbound: .direct),
            RoutingRule(type: .ipCidr, value: "127.0.0.0/8", outbound: .direct),
            RoutingRule(type: .domainSuffix, value: "local", outbound: .direct),
            RoutingRule(type: .domainSuffix, value: "localhost", outbound: .direct)
        ],
        isBuiltIn: true
    )
}
