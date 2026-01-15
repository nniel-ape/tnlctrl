//
//  Hysteria2Template.swift
//  TunnelMaster
//
//  Hysteria2 server deployment template using native tobyxdd/hysteria container.
//

import Foundation

struct Hysteria2Template: ProtocolTemplate {
    let protocolType: ProxyProtocol = .hysteria2
    let description = "High-speed UDP protocol with built-in obfuscation and masquerade"
    let defaultImage = "tobyxdd/hysteria:v2"
    let requiredPorts = [443]

    /// Hysteria2 uses YAML configuration, not JSON
    var configFileName: String { "hysteria.yaml" }

    /// Requires host network mode for optimal UDP performance
    var requiresHostNetwork: Bool { true }

    func generateServerConfig(settings: DeploymentSettings) -> String {
        var lines: [String] = [
            "listen: :\(settings.port)",
            "",
            "tls:",
            "  cert: /etc/hysteria/cert.pem",
            "  key: /etc/hysteria/key.pem",
            "",
            "auth:",
            "  type: password",
            "  password: \(settings.password)"
        ]

        // Add obfuscation if enabled
        if !settings.hysteriaObfsType.isEmpty {
            lines.append(contentsOf: [
                "",
                "obfs:",
                "  type: \(settings.hysteriaObfsType)",
                "  salamander:",
                "    password: \(settings.hysteriaObfsPassword)"
            ])
        }

        // Add bandwidth limits if set
        if !settings.hysteriaBandwidthUp.isEmpty || !settings.hysteriaBandwidthDown.isEmpty {
            let up = settings.hysteriaBandwidthUp.isEmpty ? "100" : settings.hysteriaBandwidthUp
            let down = settings.hysteriaBandwidthDown.isEmpty ? "100" : settings.hysteriaBandwidthDown
            lines.append(contentsOf: [
                "",
                "bandwidth:",
                "  up: \(up) mbps",
                "  down: \(down) mbps"
            ])
        }

        // Add masquerade for failed auth
        if !settings.sni.isEmpty {
            lines.append(contentsOf: [
                "",
                "masquerade:",
                "  type: proxy",
                "  proxy:",
                "    url: https://\(settings.sni)",
                "    rewriteHost: true"
            ])
        }

        return lines.joined(separator: "\n")
    }

    func generateClientService(settings: DeploymentSettings) -> Service {
        var serviceSettings: [String: AnyCodableValue] = [
            "password": .string(settings.password),
            "tls": .bool(true),
            "sni": .string(settings.sni.isEmpty ? settings.serverHost : settings.sni)
        ]

        if !settings.hysteriaObfsType.isEmpty {
            serviceSettings["obfs_type"] = .string(settings.hysteriaObfsType)
            serviceSettings["obfs"] = .string(settings.hysteriaObfsPassword)
        }

        if !settings.hysteriaBandwidthUp.isEmpty {
            serviceSettings["up"] = .string(settings.hysteriaBandwidthUp)
        }
        if !settings.hysteriaBandwidthDown.isEmpty {
            serviceSettings["down"] = .string(settings.hysteriaBandwidthDown)
        }

        return Service(
            name: "Hysteria2 - \(settings.serverHost)",
            protocol: .hysteria2,
            server: settings.serverHost,
            port: settings.port,
            settings: serviceSettings
        )
    }

    func generateDockerRunArgs(settings: DeploymentSettings) -> [String] {
        // Use host network mode for better UDP performance
        [
            "-d",
            "--name", settings.containerName,
            "--restart", "unless-stopped",
            "--network", "host",
            "-v", "/etc/hysteria-\(settings.containerName):/etc/hysteria:ro",
            defaultImage,
            "server", "-c", "/etc/hysteria/hysteria.yaml"
        ]
    }
}
