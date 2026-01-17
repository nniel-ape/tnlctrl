//
//  ProtocolTemplate.swift
//  TunnelMaster
//
//  Base protocol and settings for server deployment templates.
//

import Foundation

// MARK: - Protocol Template

protocol ProtocolTemplate {
    var protocolType: ProxyProtocol { get }
    var displayName: String { get }
    var description: String { get }
    var defaultImage: String { get }
    var requiredPorts: [Int] { get }

    func generateServerConfig(settings: DeploymentSettings) -> String
    func generateClientService(settings: DeploymentSettings) -> Service
    func generateDockerRunArgs(settings: DeploymentSettings) -> [String]
}

extension ProtocolTemplate {
    var displayName: String { protocolType.displayName }
}

// MARK: - Deployment Settings

struct DeploymentSettings: Sendable {
    var serverHost: String
    var port: Int
    var uuid: String
    var password: String
    var containerName: String
    var serviceName = ""

    // TLS settings
    var tlsEnabled = true
    var sni = ""

    // VLESS Reality settings
    var realityEnabled = false
    var realityPrivateKey = ""
    var realityPublicKey = ""
    var realityShortId = ""

    // Protocol-specific
    var method = "aes-256-gcm" // Shadowsocks
    var flow = "xtls-rprx-vision" // VLESS

    // Hysteria2 settings
    var hysteriaBandwidthUp = "100"
    var hysteriaBandwidthDown = "100"
    var hysteriaObfsType = "" // "salamander" or empty
    var hysteriaObfsPassword = ""

    // WireGuard settings
    var wgAdminPassword = ""
    var wgDefaultDNS = "1.1.1.1"
    var wgAllowedIPs = "0.0.0.0/0"

    init(serverHost: String, port: Int) {
        self.serverHost = serverHost
        self.port = port
        self.uuid = UUID().uuidString
        self.password = Self.generateSecurePassword()
        self.containerName = "tunnelmaster-\(Int.random(in: 1000 ... 9999))"
        self.sni = serverHost
    }

    static func generateSecurePassword(length: Int = 24) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0 ..< length).compactMap { _ in chars.randomElement() })
    }
}

// MARK: - Template Registry

enum ProtocolTemplates {
    static let all: [ProtocolTemplate] = [
        VLESSTemplate(),
        VMESSTemplate(),
        TrojanTemplate(),
        ShadowsocksTemplate(),
        Hysteria2Template(),
        WireGuardTemplate()
    ]

    /// Protocols that can be deployed via the wizard
    static var deployableProtocols: [ProxyProtocol] {
        all.map(\.protocolType)
    }

    static func template(for protocol: ProxyProtocol) -> ProtocolTemplate? {
        all.first { $0.protocolType == `protocol` }
    }
}
