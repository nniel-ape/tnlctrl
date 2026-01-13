//
//  SingBoxConfigBuilder.swift
//  TunnelMaster
//
//  Builds sing-box JSON configuration from app models.
//

import Foundation

struct SingBoxConfigBuilder {
    private let services: [Service]
    private let tunnelConfig: TunnelConfig
    private let keychainManager: KeychainManager

    init(services: [Service], tunnelConfig: TunnelConfig, keychainManager: KeychainManager = .shared) {
        self.services = services
        self.tunnelConfig = tunnelConfig
        self.keychainManager = keychainManager
    }

    // MARK: - Build

    func build() async throws -> String {
        var config: [String: Any] = [:]

        config["log"] = buildLog()
        config["dns"] = buildDNS()
        config["inbounds"] = buildInbounds()
        config["outbounds"] = try await buildOutbounds()
        config["route"] = buildRoute()
        config["experimental"] = buildExperimental()

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw ConfigBuilderError.serializationFailed
        }
        return json
    }

    // MARK: - Log

    private func buildLog() -> [String: Any] {
        [
            "level": "info",
            "timestamp": true
        ]
    }

    // MARK: - DNS

    private func buildDNS() -> [String: Any] {
        [
            "servers": [
                [
                    "tag": "dns-proxy",
                    "address": "https://1.1.1.1/dns-query",
                    "detour": "proxy"
                ],
                [
                    "tag": "dns-direct",
                    "address": "https://dns.google/dns-query",
                    "detour": "direct"
                ],
                [
                    "tag": "dns-block",
                    "address": "rcode://success"
                ]
            ],
            "rules": [
                [
                    "outbound": "any",
                    "server": "dns-direct"
                ]
            ],
            "final": "dns-proxy"
        ]
    }

    // MARK: - Inbounds

    private func buildInbounds() -> [[String: Any]] {
        [
            [
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun199",
                "mtu": 9000,
                "auto_route": true,
                "strict_route": true,
                "stack": "system",
                "sniff": true,
                "sniff_override_destination": false
            ]
        ]
    }

    // MARK: - Outbounds

    private func buildOutbounds() async throws -> [[String: Any]] {
        var outbounds: [[String: Any]] = []

        // Build chain outbound if configured
        if !tunnelConfig.chain.isEmpty {
            let chainOutbound = try await buildChainOutbound()
            outbounds.append(chainOutbound)
        }

        // Build proxy outbound (selector or single)
        let enabledServices = services.filter { $0.isEnabled }
        if enabledServices.count > 1 {
            // Selector for multiple services
            let selector = buildSelectorOutbound(services: enabledServices)
            outbounds.append(selector)
        }

        // Build individual service outbounds
        for service in enabledServices {
            let outbound = try await buildServiceOutbound(service)
            outbounds.append(outbound)
        }

        // Standard outbounds
        outbounds.append(["tag": "direct", "type": "direct"])
        outbounds.append(["tag": "block", "type": "block"])

        return outbounds
    }

    private func buildChainOutbound() async throws -> [String: Any] {
        // Build chain with detour references
        let chainServices = tunnelConfig.chain.compactMap { chainId in
            services.first { $0.id == chainId }
        }

        guard !chainServices.isEmpty else {
            throw ConfigBuilderError.emptyChain
        }

        // Create chain outbound using first service with detour to next
        // sing-box chains work by setting detour on each outbound
        let chainOutbound: [String: Any] = [
            "tag": "chain",
            "type": "selector",
            "outbounds": [chainServices.first!.id.uuidString.lowercased()]
        ]

        return chainOutbound
    }

    private func buildSelectorOutbound(services: [Service]) -> [String: Any] {
        [
            "tag": "proxy",
            "type": "selector",
            "outbounds": services.map { $0.id.uuidString.lowercased() },
            "default": services.first?.id.uuidString.lowercased() ?? ""
        ]
    }

    private func buildServiceOutbound(_ service: Service) async throws -> [String: Any] {
        var outbound: [String: Any] = [
            "tag": service.id.uuidString.lowercased(),
            "type": service.protocol.singBoxType,
            "server": service.server,
            "server_port": service.port
        ]

        // Add protocol-specific settings
        switch service.protocol {
        case .vless:
            try await addVLESSSettings(to: &outbound, service: service)
        case .vmess:
            try await addVMessSettings(to: &outbound, service: service)
        case .trojan:
            try await addTrojanSettings(to: &outbound, service: service)
        case .shadowsocks:
            try await addShadowsocksSettings(to: &outbound, service: service)
        case .socks5:
            try await addSOCKS5Settings(to: &outbound, service: service)
        case .wireguard:
            try await addWireGuardSettings(to: &outbound, service: service)
        case .hysteria2:
            try await addHysteria2Settings(to: &outbound, service: service)
        }

        // Add TLS settings if present
        if let tlsSettings = buildTLSSettings(service: service) {
            outbound["tls"] = tlsSettings
        }

        // Add transport settings if present
        if let transportSettings = buildTransportSettings(service: service) {
            outbound["transport"] = transportSettings
        }

        // Add detour for chain
        if let detourIndex = tunnelConfig.chain.firstIndex(of: service.id),
           detourIndex + 1 < tunnelConfig.chain.count {
            let nextServiceId = tunnelConfig.chain[detourIndex + 1]
            outbound["detour"] = nextServiceId.uuidString.lowercased()
        }

        return outbound
    }

    // MARK: - Protocol-Specific Settings

    private func addVLESSSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let uuid = try? await keychainManager.get( credRef) {
            outbound["uuid"] = uuid
        } else if let uuid = service.settings["uuid"]?.stringValue {
            outbound["uuid"] = uuid
        }

        if let flow = service.settings["flow"]?.stringValue {
            outbound["flow"] = flow
        }
    }

    private func addVMessSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let uuid = try? await keychainManager.get( credRef) {
            outbound["uuid"] = uuid
        } else if let uuid = service.settings["uuid"]?.stringValue {
            outbound["uuid"] = uuid
        }

        if let alterId = service.settings["alterId"]?.intValue {
            outbound["alter_id"] = alterId
        } else {
            outbound["alter_id"] = 0
        }

        if let security = service.settings["security"]?.stringValue {
            outbound["security"] = security
        } else {
            outbound["security"] = "auto"
        }
    }

    private func addTrojanSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let password = try? await keychainManager.get( credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }
    }

    private func addShadowsocksSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let method = service.settings["method"]?.stringValue {
            outbound["method"] = method
        }

        if let credRef = service.credentialRef,
           let password = try? await keychainManager.get( credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }
    }

    private func addSOCKS5Settings(to outbound: inout [String: Any], service: Service) async throws {
        if let username = service.settings["username"]?.stringValue {
            outbound["username"] = username
        }

        if let credRef = service.credentialRef,
           let password = try? await keychainManager.get( credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }
    }

    private func addWireGuardSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let privateKey = try? await keychainManager.get( credRef) {
            outbound["private_key"] = privateKey
        } else if let privateKey = service.settings["privateKey"]?.stringValue {
            outbound["private_key"] = privateKey
        }

        if let publicKey = service.settings["publicKey"]?.stringValue {
            outbound["peer_public_key"] = publicKey
        }

        if let preSharedKey = service.settings["preSharedKey"]?.stringValue {
            outbound["pre_shared_key"] = preSharedKey
        }

        if let reserved = service.settings["reserved"]?.stringValue {
            // Parse reserved bytes (comma-separated)
            let bytes = reserved.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !bytes.isEmpty {
                outbound["reserved"] = bytes
            }
        }

        // Local addresses
        var localAddresses: [String] = []
        if let ipv4 = service.settings["localAddressIPv4"]?.stringValue {
            localAddresses.append(ipv4)
        }
        if let ipv6 = service.settings["localAddressIPv6"]?.stringValue {
            localAddresses.append(ipv6)
        }
        if !localAddresses.isEmpty {
            outbound["local_address"] = localAddresses
        }

        if let mtu = service.settings["mtu"]?.intValue {
            outbound["mtu"] = mtu
        }
    }

    private func addHysteria2Settings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let password = try? await keychainManager.get( credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }

        if let up = service.settings["up"]?.stringValue {
            outbound["up_mbps"] = Int(up) ?? 100
        }

        if let down = service.settings["down"]?.stringValue {
            outbound["down_mbps"] = Int(down) ?? 100
        }

        if let obfs = service.settings["obfs"]?.stringValue, !obfs.isEmpty {
            outbound["obfs"] = [
                "type": "salamander",
                "password": obfs
            ]
        }
    }

    // MARK: - TLS Settings

    private func buildTLSSettings(service: Service) -> [String: Any]? {
        // Check if TLS is enabled (default true for most protocols)
        let tlsEnabled = service.settings["tls"]?.boolValue ?? (service.protocol != .socks5 && service.protocol != .shadowsocks)

        guard tlsEnabled else { return nil }

        var tls: [String: Any] = ["enabled": true]

        if let sni = service.settings["sni"]?.stringValue {
            tls["server_name"] = sni
        }

        if let alpn = service.settings["alpn"]?.stringValue {
            tls["alpn"] = alpn.split(separator: ",").map { String($0) }
        }

        if let insecure = service.settings["allowInsecure"]?.boolValue {
            tls["insecure"] = insecure
        }

        if let fingerprint = service.settings["fingerprint"]?.stringValue {
            tls["utls"] = ["enabled": true, "fingerprint": fingerprint]
        }

        if let reality = service.settings["reality"]?.boolValue, reality {
            var realitySettings: [String: Any] = ["enabled": true]
            if let publicKey = service.settings["realityPublicKey"]?.stringValue {
                realitySettings["public_key"] = publicKey
            }
            if let shortId = service.settings["realityShortId"]?.stringValue {
                realitySettings["short_id"] = shortId
            }
            tls["reality"] = realitySettings
        }

        return tls
    }

    // MARK: - Transport Settings

    private func buildTransportSettings(service: Service) -> [String: Any]? {
        guard let network = service.settings["network"]?.stringValue else { return nil }

        switch network {
        case "ws":
            var ws: [String: Any] = ["type": "ws"]
            if let path = service.settings["wsPath"]?.stringValue {
                ws["path"] = path
            }
            if let host = service.settings["wsHost"]?.stringValue {
                ws["headers"] = ["Host": host]
            }
            return ws

        case "grpc":
            var grpc: [String: Any] = ["type": "grpc"]
            if let serviceName = service.settings["grpcServiceName"]?.stringValue {
                grpc["service_name"] = serviceName
            }
            return grpc

        case "http", "h2":
            var http: [String: Any] = ["type": "http"]
            if let path = service.settings["httpPath"]?.stringValue {
                http["path"] = path
            }
            if let host = service.settings["httpHost"]?.stringValue {
                http["host"] = [host]
            }
            return http

        case "quic":
            return ["type": "quic"]

        default:
            return nil
        }
    }

    // MARK: - Route

    private func buildRoute() -> [String: Any] {
        var route: [String: Any] = [:]

        // Build rules
        var rules: [[String: Any]] = []

        // Add DNS rules
        rules.append([
            "protocol": "dns",
            "outbound": "dns-out"
        ])

        // Add user-defined rules
        for rule in tunnelConfig.rules {
            let singBoxRule = buildRule(rule)
            rules.append(singBoxRule)
        }

        route["rules"] = rules

        // Set final outbound based on mode
        switch tunnelConfig.mode {
        case .full:
            route["final"] = tunnelConfig.chain.isEmpty ? "proxy" : "chain"
        case .split:
            route["final"] = "direct"
        }

        route["auto_detect_interface"] = true

        return route
    }

    private func buildRule(_ rule: RoutingRule) -> [String: Any] {
        var singBoxRule: [String: Any] = [:]

        // Map rule type to sing-box key
        switch rule.type {
        case .processName:
            singBoxRule["process_name"] = [rule.value]
        case .processPath:
            singBoxRule["process_path"] = [rule.value]
        case .domain:
            singBoxRule["domain"] = [rule.value]
        case .domainSuffix:
            singBoxRule["domain_suffix"] = [rule.value]
        case .domainKeyword:
            singBoxRule["domain_keyword"] = [rule.value]
        case .ipCidr:
            singBoxRule["ip_cidr"] = [rule.value]
        case .geoip:
            singBoxRule["geoip"] = [rule.value]
        case .geosite:
            singBoxRule["geosite"] = [rule.value]
        }

        // Map outbound
        switch rule.outbound {
        case .direct:
            singBoxRule["outbound"] = "direct"
        case .proxy:
            singBoxRule["outbound"] = tunnelConfig.chain.isEmpty ? "proxy" : "chain"
        case .block:
            singBoxRule["outbound"] = "block"
        }

        return singBoxRule
    }

    // MARK: - Experimental

    private func buildExperimental() -> [String: Any] {
        [
            "cache_file": [
                "enabled": true,
                "path": "cache.db"
            ]
        ]
    }
}

// MARK: - ProxyProtocol Extension

private extension ProxyProtocol {
    var singBoxType: String {
        switch self {
        case .vless: "vless"
        case .vmess: "vmess"
        case .trojan: "trojan"
        case .shadowsocks: "shadowsocks"
        case .socks5: "socks"
        case .wireguard: "wireguard"
        case .hysteria2: "hysteria2"
        }
    }
}

// MARK: - Errors

enum ConfigBuilderError: LocalizedError {
    case serializationFailed
    case emptyChain
    case noEnabledServices

    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            "Failed to serialize configuration to JSON"
        case .emptyChain:
            "Proxy chain contains no valid services"
        case .noEnabledServices:
            "No enabled services found"
        }
    }
}
