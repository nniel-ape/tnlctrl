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

    // TLS settings
    var tlsEnabled: Bool = true
    var sni: String = ""

    // VLESS Reality settings
    var realityEnabled: Bool = false
    var realityPrivateKey: String = ""
    var realityPublicKey: String = ""
    var realityShortId: String = ""

    // Protocol-specific
    var method: String = "aes-256-gcm"  // Shadowsocks
    var flow: String = "xtls-rprx-vision"  // VLESS

    init(serverHost: String, port: Int) {
        self.serverHost = serverHost
        self.port = port
        self.uuid = UUID().uuidString
        self.password = Self.generateSecurePassword()
        self.containerName = "tunnelmaster-\(Int.random(in: 1000...9999))"
        self.sni = serverHost
    }

    static func generateSecurePassword(length: Int = 24) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}

// MARK: - Template Registry

enum ProtocolTemplates {
    static let all: [ProtocolTemplate] = [
        VLESSTemplate(),
        TrojanTemplate(),
        ShadowsocksTemplate()
    ]

    static func template(for protocol: ProxyProtocol) -> ProtocolTemplate? {
        all.first { $0.protocolType == `protocol` }
    }
}
