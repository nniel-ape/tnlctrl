//
//  TrojanTemplate.swift
//  TunnelMaster
//
//  Trojan server deployment template using sing-box.
//

import Foundation

struct TrojanTemplate: ProtocolTemplate {
    let protocolType: ProxyProtocol = .trojan
    let description = "Disguises traffic as HTTPS, requires TLS certificate"
    let defaultImage = "ghcr.io/sagernet/sing-box:latest"
    let requiredPorts = [443]

    func generateServerConfig(settings: DeploymentSettings) -> String {
        let config: [String: Any] = [
            "log": ["level": "info"],
            "inbounds": [[
                "type": "trojan",
                "tag": "trojan-in",
                "listen": "::",
                "listen_port": settings.port,
                "users": [[
                    "password": settings.password
                ]],
                "tls": [
                    "enabled": true,
                    "server_name": settings.sni,
                    "certificate_path": "/etc/sing-box/cert.pem",
                    "key_path": "/etc/sing-box/key.pem"
                ]
            ]],
            "outbounds": [
                ["type": "direct", "tag": "direct"]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    func generateClientService(settings: DeploymentSettings) -> Service {
        Service(
            name: "Trojan - \(settings.serverHost)",
            protocol: .trojan,
            server: settings.serverHost,
            port: settings.port,
            settings: [
                "password": .string(settings.password),
                "tls": .bool(true),
                "sni": .string(settings.sni)
            ]
        )
    }

    func generateDockerRunArgs(settings: DeploymentSettings) -> [String] {
        let configPath = "/etc/sing-box/config.json"

        return [
            "-d",
            "--name", settings.containerName,
            "--restart", "unless-stopped",
            "-p", "\(settings.port):\(settings.port)",
            "-v", "/etc/sing-box:/etc/sing-box:ro",
            defaultImage,
            "run", "-c", configPath
        ]
    }
}
