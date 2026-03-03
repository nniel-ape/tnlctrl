//
//  VMESSTemplate.swift
//  tnl_ctrl
//
//  VMess server deployment template using sing-box.
//

import Foundation

struct VMESSTemplate: ProtocolTemplate {
    let protocolType: ProxyProtocol = .vmess
    let description = "Popular V2Ray protocol with flexible transport options"
    let requiredPorts = [443]

    func generateServerConfig(settings: DeploymentSettings) -> String {
        var inbound: [String: Any] = [
            "type": "vmess",
            "tag": "vmess-in",
            "listen": "::",
            "listen_port": settings.port,
            "users": [
                [
                    "name": "user",
                    "uuid": settings.uuid,
                    "alterId": 0
                ]
            ]
        ]

        // Add TLS if enabled
        if settings.tlsEnabled {
            inbound["tls"] = [
                "enabled": true,
                "server_name": settings.sni,
                "certificate_path": "/etc/sing-box/cert.pem",
                "key_path": "/etc/sing-box/key.pem"
            ]
        }

        let config: [String: Any] = [
            "log": ["level": "info"],
            "inbounds": [inbound],
            "outbounds": [
                [
                    "type": "direct",
                    "tag": "direct"
                ]
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
            name: settings.serviceName.isEmpty ? "VMess - \(settings.serverHost)" : settings.serviceName,
            protocol: .vmess,
            server: settings.serverHost,
            port: settings.port,
            settings: [
                "uuid": .string(settings.uuid),
                "alterId": .int(0),
                "security": .string("auto"),
                "tls": .bool(settings.tlsEnabled),
                "sni": .string(settings.sni),
                "containerName": .string(settings.containerName)
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
