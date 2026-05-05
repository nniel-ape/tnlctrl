//
//  SingBoxConfigBuilder.swift
//  tnl_ctrl
//
//  Builds sing-box JSON configuration from app models.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "SingBoxConfigBuilder")

struct SingBoxConfigBuilder {
    private let services: [Service]
    private let tunnelConfig: TunnelConfig
    private let appSettings: AppSettings
    private let keychainManager: any KeychainManaging

    init(
        services: [Service],
        tunnelConfig: TunnelConfig,
        appSettings: AppSettings = .default,
        keychainManager: any KeychainManaging = KeychainManager.shared
    ) {
        self.services = services
        self.tunnelConfig = tunnelConfig
        self.appSettings = appSettings
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

        if appSettings.certificateStore != .system {
            config["certificate"] = ["store": appSettings.certificateStore.rawValue]
        }

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
                    "type": "local",
                    "tag": "dns-local"
                ],
                [
                    "type": "https",
                    "tag": "dns-proxy",
                    "server": "1.1.1.1",
                    "detour": "proxy"
                ]
            ],
            "strategy": "prefer_ipv4",
            "final": "dns-proxy"
        ]
    }

    // MARK: - Inbounds

    private func buildInbounds() -> [[String: Any]] {
        // Collect IPs to exclude from TUN routing (proxy server IPs for loop prevention)
        var excludeIPs: [String] = []

        // Add proxy server IPs (skip domain names - they'll use auto_detect_interface)
        for service in services where isIPAddress(service.server) {
            let prefix = isIPv6Address(service.server) ? 128 : 32
            excludeIPs.append("\(service.server)/\(prefix)")
        }

        var tun: [String: Any] = [
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "utun199",
            "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
            "mtu": 1400,
            "auto_route": true,
            "stack": "gvisor"
        ]

        // Exclude IPs from TUN routing to prevent loops
        tun["route_exclude_address"] = excludeIPs

        return [tun]
    }

    // MARK: - Outbounds

    private func buildOutbounds() async throws -> [[String: Any]] {
        var outbounds: [[String: Any]] = []

        // Build chain outbounds if chaining is enabled and configured
        // Chain-hop outbounds are separate from service outbounds so that
        // detour doesn't affect the proxy selector (used by DNS)
        if tunnelConfig.chainEnabled, !tunnelConfig.chain.isEmpty {
            // Validate chain services exist
            guard !tunnelConfig.chain.isEmpty else {
                throw ConfigBuilderError.emptyChain
            }
            for (index, chainId) in tunnelConfig.chain.enumerated() {
                guard services.contains(where: { $0.id == chainId }) else {
                    throw ConfigBuilderError.missingChainService(index: index + 1)
                }
            }

            // Chain selector
            outbounds.append([
                "tag": "chain",
                "type": "selector",
                "outbounds": ["chain-hop-0"],
                "default": "chain-hop-0"
            ])

            // Build chain-hop outbounds with detour links
            for (index, chainId) in tunnelConfig.chain.enumerated() {
                let service = services.first { $0.id == chainId }!
                var hop = try await buildServiceOutbound(service)
                hop["tag"] = "chain-hop-\(index)"
                if index + 1 < tunnelConfig.chain.count {
                    hop["detour"] = "chain-hop-\(index + 1)"
                }
                outbounds.append(hop)
            }
        }

        // Build proxy outbound (selector)
        // Always create proxy selector (even with single service) since DNS/route reference it
        if !services.isEmpty {
            let selector = buildSelectorOutbound(services: services)
            outbounds.append(selector)
        }

        // Build individual service outbounds (no detour — used by proxy selector for DNS)
        for service in services {
            let outbound = try await buildServiceOutbound(service)
            outbounds.append(outbound)
        }

        // Standard outbounds
        outbounds.append(["tag": "direct", "type": "direct"])
        outbounds.append(["tag": "block", "type": "block"])

        return outbounds
    }

    private func buildSelectorOutbound(services: [Service]) -> [String: Any] {
        // Use explicitly selected service, or fall back to first enabled
        let defaultService: Service? = if let selectedId = tunnelConfig.selectedServiceId,
                                          let selected = services.first(where: { $0.id == selectedId }) {
            selected
        } else {
            services.first
        }

        return [
            "tag": "proxy",
            "type": "selector",
            "outbounds": services.map { $0.id.uuidString.lowercased() },
            "default": defaultService?.id.uuidString.lowercased() ?? ""
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

        return outbound
    }

    // MARK: - Protocol-Specific Settings

    private func addVLESSSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let uuid = try? await keychainManager.get(credRef) {
            outbound["uuid"] = uuid
        } else if let uuid = service.settings["uuid"]?.stringValue {
            outbound["uuid"] = uuid
        }

        if let flow = service.settings["flow"]?.stringValue, !flow.isEmpty {
            outbound["flow"] = flow
        }
    }

    private func addVMessSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let uuid = try? await keychainManager.get(credRef) {
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
        if let credRef = service.credentialRef {
            do {
                if let password = try await keychainManager.get(credRef) {
                    outbound["password"] = password
                } else {
                    throw ConfigBuilderError.credentialNotFound(credRef)
                }
            } catch {
                logger.error("Failed to retrieve Trojan password for credRef \(credRef, privacy: .public): \(error)")
                throw error
            }
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        } else {
            throw ConfigBuilderError.missingCredential("trojan", service.name)
        }
    }

    private func addShadowsocksSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let method = service.settings["method"]?.stringValue {
            outbound["method"] = method
        }

        if let credRef = service.credentialRef {
            do {
                if let password = try await keychainManager.get(credRef) {
                    outbound["password"] = password
                } else {
                    throw ConfigBuilderError.credentialNotFound(credRef)
                }
            } catch {
                logger.error("Failed to retrieve Shadowsocks password for credRef \(credRef, privacy: .public): \(error)")
                throw error
            }
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        } else {
            throw ConfigBuilderError.missingCredential("shadowsocks", service.name)
        }

        if let plugin = service.settings["plugin"]?.stringValue, !plugin.isEmpty {
            outbound["plugin"] = plugin
            if let pluginOpts = service.settings["pluginOpts"]?.stringValue, !pluginOpts.isEmpty {
                outbound["plugin_opts"] = pluginOpts
            }
        }

        if let udpOverTcp = service.settings["udpOverTcp"]?.boolValue, udpOverTcp {
            outbound["udp_over_tcp"] = true
        }
    }

    private func addSOCKS5Settings(to outbound: inout [String: Any], service: Service) async throws {
        if let username = service.settings["username"]?.stringValue {
            outbound["username"] = username
        }

        if let credRef = service.credentialRef,
           let password = try? await keychainManager.get(credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }
    }

    private func addWireGuardSettings(to outbound: inout [String: Any], service: Service) async throws {
        if let credRef = service.credentialRef,
           let privateKey = try? await keychainManager.get(credRef) {
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
           let password = try? await keychainManager.get(credRef) {
            outbound["password"] = password
        } else if let password = service.settings["password"]?.stringValue {
            outbound["password"] = password
        }

        // Only set bandwidth when explicitly configured; omitting enables BBR congestion control
        if let up = service.settings["up"]?.stringValue, !up.isEmpty, let upMbps = Int(up) {
            outbound["up_mbps"] = upMbps
        }

        if let down = service.settings["down"]?.stringValue, !down.isEmpty, let downMbps = Int(down) {
            outbound["down_mbps"] = downMbps
        }

        if let obfs = service.settings["obfs"]?.stringValue, !obfs.isEmpty {
            outbound["obfs"] = [
                "type": "salamander",
                "password": obfs
            ]
        }

        // Port hopping: server_ports replaces server_port
        if let serverPorts = service.settings["serverPorts"]?.stringValue, !serverPorts.isEmpty {
            outbound["server_ports"] = serverPorts
            outbound.removeValue(forKey: "server_port")
        }

        if let hopInterval = service.settings["hopInterval"]?.stringValue, !hopInterval.isEmpty {
            outbound["hop_interval"] = hopInterval
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

        if let fragment = service.settings["fragment"]?.boolValue, fragment {
            tls["fragment"] = ["enabled": true]
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
            if let earlyData = service.settings["wsEarlyData"]?.stringValue,
               !earlyData.isEmpty, let size = Int(earlyData) {
                ws["max_early_data"] = size
            }
            if let earlyDataHeader = service.settings["wsEarlyDataHeader"]?.stringValue, !earlyDataHeader.isEmpty {
                ws["early_data_header_name"] = earlyDataHeader
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

        case "httpupgrade":
            var httpUpgrade: [String: Any] = ["type": "httpupgrade"]
            if let path = service.settings["httpUpgradePath"]?.stringValue {
                httpUpgrade["path"] = path
            }
            if let host = service.settings["httpUpgradeHost"]?.stringValue {
                httpUpgrade["host"] = host
            }
            return httpUpgrade

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

        // Hijack DNS traffic for internal resolution (sing-box 1.12+)
        rules.append([
            "protocol": "dns",
            "action": "hijack-dns"
        ])

        // Route private IPs directly (LAN traffic)
        rules.append([
            "ip_is_private": true,
            "outbound": "direct"
        ])

        // Add user-defined rules (only enabled ones)
        for rule in tunnelConfig.rules where rule.isEnabled {
            let singBoxRule = buildRule(rule)
            rules.append(singBoxRule)
        }

        route["rules"] = rules

        // Build rule_set definitions for geoip/geosite rules (sing-box 1.12+ format)
        var ruleSetTags = Set<String>()
        var ruleSets: [[String: Any]] = []

        for rule in tunnelConfig.rules where rule.isEnabled {
            let tag: String?
            let url: String?

            switch rule.type {
            case .geoip:
                tag = "geoip-\(rule.value)"
                url = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-\(rule.value).srs"
            case .geosite:
                tag = "geosite-\(rule.value)"
                url = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-\(rule.value).srs"
            default:
                tag = nil
                url = nil
            }

            if let tag, let url, !ruleSetTags.contains(tag) {
                ruleSetTags.insert(tag)
                ruleSets.append([
                    "tag": tag,
                    "type": "remote",
                    "format": "binary",
                    "url": url,
                    "download_detour": "direct"
                ])
            }
        }

        if !ruleSets.isEmpty {
            route["rule_set"] = ruleSets
        }

        // Set final outbound based on mode and config
        let useChain = tunnelConfig.chainEnabled && !tunnelConfig.chain.isEmpty
        switch tunnelConfig.mode {
        case .full:
            route["final"] = useChain ? "chain" : "proxy"
        case .split:
            // Use finalOutbound from config
            switch tunnelConfig.finalOutbound {
            case .direct:
                route["final"] = "direct"
            case .proxy:
                route["final"] = useChain ? "chain" : "proxy"
            case .block:
                route["final"] = "block"
            }
        }

        route["auto_detect_interface"] = true
        route["default_domain_resolver"] = "dns-local"

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
            singBoxRule["rule_set"] = ["geoip-\(rule.value)"]
        case .geosite:
            singBoxRule["rule_set"] = ["geosite-\(rule.value)"]
        }

        // Map outbound
        let useChain = tunnelConfig.chainEnabled && !tunnelConfig.chain.isEmpty
        switch rule.outbound {
        case .direct:
            singBoxRule["outbound"] = "direct"
        case .proxy:
            singBoxRule["outbound"] = useChain ? "chain" : "proxy"
        case .block:
            singBoxRule["outbound"] = "block"
        }

        return singBoxRule
    }

    // MARK: - Helpers

    private func isIPAddress(_ string: String) -> Bool {
        isIPv4Address(string) || isIPv6Address(string)
    }

    private func isIPv4Address(_ string: String) -> Bool {
        var sin = sockaddr_in()
        return inet_pton(AF_INET, string, &sin.sin_addr) == 1
    }

    private func isIPv6Address(_ string: String) -> Bool {
        var sin6 = sockaddr_in6()
        return inet_pton(AF_INET6, string, &sin6.sin6_addr) == 1
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

extension ProxyProtocol {
    fileprivate var singBoxType: String {
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
    case missingChainService(index: Int)
    case credentialNotFound(String)
    case missingCredential(String, String)

    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            "Failed to serialize configuration to JSON"
        case .emptyChain:
            "Proxy chain contains no valid services"
        case let .missingChainService(index):
            "Chain service #\(index) no longer exists"
        case let .credentialNotFound(ref):
            "Credential not found in Keychain: \(ref)"
        case let .missingCredential(proto, name):
            "Missing credential for \(proto) service '\(name)'"
        }
    }
}
