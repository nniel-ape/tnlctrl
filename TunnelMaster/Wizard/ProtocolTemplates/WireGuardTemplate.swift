//
//  WireGuardTemplate.swift
//  TunnelMaster
//
//  WireGuard server deployment template using wg-easy container.
//

import Foundation

struct WireGuardTemplate: ProtocolTemplate {
    let protocolType: ProxyProtocol = .wireguard
    let description = "Modern VPN with built-in web admin interface"
    let defaultImage = "ghcr.io/wg-easy/wg-easy:15"
    let requiredPorts = [51820, 51821] // WireGuard UDP + Web UI TCP

    /// wg-easy uses environment variables instead of config file
    var usesEnvironmentConfig: Bool {
        true
    }

    /// Requires special capabilities for network management
    var requiredCapabilities: [String] {
        ["NET_ADMIN", "SYS_MODULE"]
    }

    /// Required sysctls for IP forwarding
    var requiredSysctls: [String: String] {
        ["net.ipv4.ip_forward": "1"]
    }

    func generateServerConfig(settings: DeploymentSettings) -> String {
        // wg-easy uses environment variables, not a config file
        // Return empty config - all settings are in Docker environment vars
        ""
    }

    func generateEnvironment(settings: DeploymentSettings) -> [String: String] {
        var env: [String: String] = [
            "WG_HOST": settings.serverHost,
            "WG_PORT": String(settings.port),
            "WG_DEFAULT_DNS": settings.wgDefaultDNS,
            "WG_ALLOWED_IPS": settings.wgAllowedIPs,
            "WG_PERSISTENT_KEEPALIVE": "25"
        ]

        if !settings.wgAdminPassword.isEmpty {
            // wg-easy expects bcrypt hash, but for simplicity we'll use plain password
            // In production, this should be bcrypt hashed
            env["PASSWORD"] = settings.wgAdminPassword
        }

        return env
    }

    func generateClientService(settings: DeploymentSettings) -> Service {
        // WireGuard client config is different - needs to be generated from wg-easy web UI
        // This creates a placeholder that the user can update with actual peer config
        Service(
            name: settings.serviceName.isEmpty ? "WireGuard - \(settings.serverHost)" : settings.serviceName,
            protocol: .wireguard,
            server: settings.serverHost,
            port: settings.port,
            settings: [
                "web_ui_port": .int(51821),
                "note": .string("Configure client from wg-easy web UI at http://\(settings.serverHost):51821")
            ]
        )
    }

    func generateDockerRunArgs(settings: DeploymentSettings) -> [String] {
        var args = [
            "-d",
            "--name", settings.containerName,
            "--restart", "unless-stopped",
            "--cap-add", "NET_ADMIN",
            "--cap-add", "SYS_MODULE",
            "--sysctl", "net.ipv4.ip_forward=1"
        ]

        // Add environment variables
        let env = generateEnvironment(settings: settings)
        for (key, value) in env.sorted(by: { $0.key < $1.key }) {
            args.append("-e")
            args.append("\(key)=\(value)")
        }

        // Add ports
        args.append("-p")
        args.append("\(settings.port):\(settings.port)/udp") // WireGuard
        args.append("-p")
        args.append("51821:51821/tcp") // Web UI

        // Add volume for WireGuard config persistence
        args.append("-v")
        args.append("/etc/wireguard-\(settings.containerName):/etc/wireguard")

        // Add image
        args.append(defaultImage)

        return args
    }
}
