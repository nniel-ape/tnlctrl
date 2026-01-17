//
//  RulePreset.swift
//  TunnelMaster
//

import Foundation

struct RulePreset: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var description: String
    var rules: [RoutingRule]
    let isBuiltIn: Bool
    var icon: String
    var color: PresetColor

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        rules: [RoutingRule],
        isBuiltIn: Bool = false,
        icon: String = "list.bullet.rectangle",
        color: PresetColor = .blue
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.rules = rules
        self.isBuiltIn = isBuiltIn
        self.icon = icon
        self.color = color
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case rules
        case isBuiltIn
        case icon
        case color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.rules = try container.decode([RoutingRule].self, forKey: .rules)
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "list.bullet.rectangle"
        self.color = try container.decodeIfPresent(PresetColor.self, forKey: .color) ?? .blue
    }
}

// MARK: - Preset Color

enum PresetColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
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
        isBuiltIn: true,
        icon: "flag",
        color: .red
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
        isBuiltIn: true,
        icon: "play.tv",
        color: .purple
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
        isBuiltIn: true,
        icon: "nosign",
        color: .red
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
        isBuiltIn: true,
        icon: "person.2",
        color: .blue
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
        isBuiltIn: true,
        icon: "network",
        color: .green
    )
}
