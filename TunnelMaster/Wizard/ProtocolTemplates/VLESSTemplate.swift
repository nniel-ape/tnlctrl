//
//  VLESSTemplate.swift
//  TunnelMaster
//
//  VLESS server deployment template using sing-box.
//

import Foundation

struct VLESSTemplate: ProtocolTemplate {
    let protocolType: ProxyProtocol = .vless
    let description = "Modern, lightweight protocol with optional Reality encryption"
    let requiredPorts = [443]

    func generateServerConfig(settings: DeploymentSettings) -> String {
        var config: [String: Any] = [
            "log": ["level": "info"],
            "inbounds": [
                [
                    "type": "vless",
                    "tag": "vless-in",
                    "listen": "::",
                    "listen_port": settings.port,
                    "users": [
                        [
                            "uuid": settings.uuid,
                            "flow": settings.flow
                        ]
                    ],
                    "tls": buildTLSConfig(settings: settings)
                ]
            ],
            "outbounds": [
                [
                    "type": "direct",
                    "tag": "direct"
                ]
            ]
        ]

        if let inbounds = config["inbounds"] as? [[String: Any]],
           var firstInbound = inbounds.first {
            if settings.realityEnabled {
                firstInbound["tls"] = buildRealityConfig(settings: settings)
            }
            config["inbounds"] = [firstInbound]
        }

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    func generateClientService(settings: DeploymentSettings) -> Service {
        var serviceSettings: [String: AnyCodableValue] = [
            "uuid": .string(settings.uuid),
            "flow": .string(settings.flow),
            "tls": .bool(settings.tlsEnabled),
            "sni": .string(settings.sni),
            "containerName": .string(settings.containerName)
        ]

        if settings.realityEnabled {
            serviceSettings["reality"] = .bool(true)
            serviceSettings["realityPublicKey"] = .string(settings.realityPublicKey)
            serviceSettings["realityShortId"] = .string(settings.realityShortId)
            serviceSettings["fingerprint"] = .string("chrome")
        }

        return Service(
            name: settings.serviceName.isEmpty ? "VLESS - \(settings.serverHost)" : settings.serviceName,
            protocol: .vless,
            server: settings.serverHost,
            port: settings.port,
            settings: serviceSettings
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

    // MARK: - Helpers

    private func buildTLSConfig(settings: DeploymentSettings) -> [String: Any] {
        [
            "enabled": settings.tlsEnabled,
            "server_name": settings.sni,
            "certificate_path": "/etc/sing-box/cert.pem",
            "key_path": "/etc/sing-box/key.pem"
        ]
    }

    private func buildRealityConfig(settings: DeploymentSettings) -> [String: Any] {
        [
            "enabled": true,
            "reality": [
                "enabled": true,
                "handshake": [
                    "server": "www.microsoft.com",
                    "server_port": 443
                ],
                "private_key": settings.realityPrivateKey,
                "short_id": [settings.realityShortId]
            ]
        ]
    }
}
