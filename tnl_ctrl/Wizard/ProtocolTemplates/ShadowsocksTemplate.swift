//
//  ShadowsocksTemplate.swift
//  tnl_ctrl
//
//  Shadowsocks server deployment template using sing-box.
//

import Foundation

struct ShadowsocksTemplate: ProtocolTemplate {
    let protocolType: ProxyProtocol = .shadowsocks
    let description = "Simple, fast encrypted tunnel with AEAD cipher support"
    let requiredPorts = [8388]

    func generateServerConfig(settings: DeploymentSettings) -> String {
        let config: [String: Any] = [
            "log": ["level": "info"],
            "inbounds": [
                [
                    "type": "shadowsocks",
                    "tag": "ss-in",
                    "listen": "::",
                    "listen_port": settings.port,
                    "method": settings.method,
                    "password": settings.password
                ]
            ],
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
            name: settings.serviceName.isEmpty ? "Shadowsocks - \(settings.serverHost)" : settings.serviceName,
            protocol: .shadowsocks,
            server: settings.serverHost,
            port: settings.port,
            settings: [
                "method": .string(settings.method),
                "password": .string(settings.password),
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
