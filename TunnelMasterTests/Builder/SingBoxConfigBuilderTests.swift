//
//  SingBoxConfigBuilderTests.swift
//  TunnelMasterTests
//
//  Comprehensive tests for SingBoxConfigBuilder covering all protocols,
//  transports, TLS options, and routing rules based on sing-box 1.12+ spec.
//

@testable import TunnelMaster
import XCTest

@MainActor
final class SingBoxConfigBuilderTests: XCTestCase {
    var mockKeychain: MockKeychainManager!

    override func setUp() async throws {
        mockKeychain = MockKeychainManager()
    }

    override func tearDown() async throws {
        await mockKeychain.reset()
        mockKeychain = nil
    }

    // MARK: - Helper

    private func makeBuilder(services: [Service], config: TunnelConfig? = nil) -> SingBoxConfigBuilder {
        SingBoxConfigBuilder(
            services: services,
            tunnelConfig: config ?? ConfigFixtures.makeDefaultTunnelConfig(),
            keychainManager: mockKeychain
        )
    }

    private func parseJSON(_ json: String) throws -> [String: Any] {
        let data = json.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func findOutbound(in outbounds: [[String: Any]], type: String) -> [String: Any]? {
        outbounds.first { $0["type"] as? String == type }
    }

    private func findOutbound(in outbounds: [[String: Any]], tag: String) -> [String: Any]? {
        outbounds.first { $0["tag"] as? String == tag }
    }

    // MARK: - Basic Structure Tests

    func testBuildContainsAllSections() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)

        XCTAssertNotNil(config["log"], "Config must contain 'log' section")
        XCTAssertNotNil(config["dns"], "Config must contain 'dns' section")
        XCTAssertNotNil(config["inbounds"], "Config must contain 'inbounds' section")
        XCTAssertNotNil(config["outbounds"], "Config must contain 'outbounds' section")
        XCTAssertNotNil(config["route"], "Config must contain 'route' section")
        XCTAssertNotNil(config["experimental"], "Config must contain 'experimental' section")
    }

    func testBuildLogSection() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let log = config["log"] as! [String: Any]

        XCTAssertEqual(log["level"] as? String, "info")
        XCTAssertEqual(log["timestamp"] as? Bool, true)
    }

    func testBuildTUNInbound() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let inbounds = config["inbounds"] as! [[String: Any]]

        XCTAssertEqual(inbounds.count, 1)
        let tun = inbounds[0]
        XCTAssertEqual(tun["type"] as? String, "tun")
        XCTAssertEqual(tun["tag"] as? String, "tun-in")
        XCTAssertEqual(tun["interface_name"] as? String, "utun199")
        XCTAssertEqual(tun["auto_route"] as? Bool, true)
        XCTAssertEqual(tun["strict_route"] as? Bool, true)
        XCTAssertEqual(tun["sniff"] as? Bool, true)
        XCTAssertEqual(tun["stack"] as? String, "system")
        XCTAssertEqual(tun["mtu"] as? Int, 9000)

        // Required since sing-box 1.11+
        let addresses = tun["address"] as? [String]
        XCTAssertNotNil(addresses, "TUN address is required for sing-box 1.11+")
        XCTAssertEqual(addresses?.count, 2, "Should have IPv4 and IPv6 addresses")
        XCTAssertTrue(addresses?.contains("172.19.0.1/30") == true)
        XCTAssertTrue(addresses?.contains("fdfe:dcba:9876::1/126") == true)
    }

    func testBuildExperimentalSection() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let experimental = config["experimental"] as! [String: Any]
        let cacheFile = experimental["cache_file"] as? [String: Any]

        XCTAssertNotNil(cacheFile)
        XCTAssertEqual(cacheFile?["enabled"] as? Bool, true)
        XCTAssertEqual(cacheFile?["path"] as? String, "cache.db")
    }

    // MARK: - DNS Tests

    func testBuildDNSSection() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let dns = config["dns"] as! [String: Any]

        let servers = dns["servers"] as! [[String: Any]]
        XCTAssertGreaterThanOrEqual(servers.count, 2, "Should have at least 2 DNS servers")

        // Check for proxy DNS
        let proxyDNS = servers.first { $0["tag"] as? String == "dns-proxy" }
        XCTAssertNotNil(proxyDNS, "Should have dns-proxy server")

        // Check for direct DNS
        let directDNS = servers.first { $0["tag"] as? String == "dns-direct" }
        XCTAssertNotNil(directDNS, "Should have dns-direct server")

        // Check rules exist
        let rules = dns["rules"] as? [[String: Any]]
        XCTAssertNotNil(rules)

        // Check final DNS
        XCTAssertEqual(dns["final"] as? String, "dns-proxy")
    }

    // MARK: - VLESS Protocol Tests

    func testBuildVLESSOutbound() async throws {
        await mockKeychain.preloadCredential("550e8400-e29b-41d4-a716-446655440000", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        XCTAssertEqual(vlessOutbound["type"] as? String, "vless")
        XCTAssertEqual(vlessOutbound["server"] as? String, "example.com")
        XCTAssertEqual(vlessOutbound["server_port"] as? Int, 443)
        XCTAssertEqual(vlessOutbound["uuid"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(vlessOutbound["flow"] as? String, "xtls-rprx-vision")

        // TLS with Reality
        let tls = vlessOutbound["tls"] as? [String: Any]
        XCTAssertNotNil(tls)
        XCTAssertEqual(tls?["enabled"] as? Bool, true)
        XCTAssertEqual(tls?["server_name"] as? String, "example.com")

        let reality = tls?["reality"] as? [String: Any]
        XCTAssertEqual(reality?["enabled"] as? Bool, true)
        XCTAssertEqual(reality?["public_key"] as? String, "abc123publickey")
    }

    func testBuildVLESSWithRealityFull() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSRealityFullService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        // Verify Reality settings
        let tls = vlessOutbound["tls"] as! [String: Any]
        XCTAssertEqual(tls["server_name"] as? String, "www.microsoft.com")

        let reality = tls["reality"] as! [String: Any]
        XCTAssertEqual(reality["enabled"] as? Bool, true)
        XCTAssertEqual(reality["public_key"] as? String, "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0")
        XCTAssertEqual(reality["short_id"] as? String, "0123456789abcdef")

        // Verify uTLS
        let utls = tls["utls"] as? [String: Any]
        XCTAssertEqual(utls?["enabled"] as? Bool, true)
        XCTAssertEqual(utls?["fingerprint"] as? String, "chrome")

        // Verify XTLS flow
        XCTAssertEqual(vlessOutbound["flow"] as? String, "xtls-rprx-vision")
    }

    func testBuildVLESSWithgRPC() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSgRPCService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let transport = vlessOutbound["transport"] as? [String: Any]
        XCTAssertNotNil(transport)
        XCTAssertEqual(transport?["type"] as? String, "grpc")
        XCTAssertEqual(transport?["service_name"] as? String, "TunService")
    }

    func testBuildVLESSWithWebSocket() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSWebSocketService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let transport = vlessOutbound["transport"] as? [String: Any]
        XCTAssertNotNil(transport)
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/vless-ws")

        let headers = transport?["headers"] as? [String: String]
        XCTAssertEqual(headers?["Host"], "vless-ws.example.com")
    }

    func testBuildVLESSWithHTTP2() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSHTTPService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let transport = vlessOutbound["transport"] as? [String: Any]
        XCTAssertNotNil(transport)
        XCTAssertEqual(transport?["type"] as? String, "http")
        XCTAssertEqual(transport?["path"] as? String, "/vless-http")

        let hosts = transport?["host"] as? [String]
        XCTAssertEqual(hosts?.first, "vless-h2.example.com")
    }

    // MARK: - VMess Protocol Tests

    func testBuildVMessOutbound() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!

        XCTAssertEqual(vmessOutbound["type"] as? String, "vmess")
        XCTAssertEqual(vmessOutbound["uuid"] as? String, "test-uuid")
        XCTAssertEqual(vmessOutbound["alter_id"] as? Int, 0)
        XCTAssertEqual(vmessOutbound["security"] as? String, "auto")

        // WebSocket transport
        let transport = vmessOutbound["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/websocket")
    }

    func testBuildVMessWithChaCha20Security() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessSecurityService(
            credentialRef: "test-cred-ref",
            security: "chacha20-poly1305"
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        XCTAssertEqual(vmessOutbound["security"] as? String, "chacha20-poly1305")
    }

    func testBuildVMessWithAES128GCM() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessSecurityService(
            credentialRef: "test-cred-ref",
            security: "aes-128-gcm"
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        XCTAssertEqual(vmessOutbound["security"] as? String, "aes-128-gcm")
    }

    func testBuildVMessWithZeroSecurity() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessSecurityService(
            credentialRef: "test-cred-ref",
            security: "zero"
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        XCTAssertEqual(vmessOutbound["security"] as? String, "zero")
    }

    func testBuildVMessWithgRPC() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessgRPCService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!

        let transport = vmessOutbound["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "grpc")
        XCTAssertEqual(transport?["service_name"] as? String, "VMGrpcService")
    }

    // MARK: - Trojan Protocol Tests

    func testBuildTrojanOutbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeTrojanService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let trojanOutbound = findOutbound(in: outbounds, type: "trojan")!

        XCTAssertEqual(trojanOutbound["password"] as? String, "password123")
        XCTAssertNotNil(trojanOutbound["tls"])

        let tls = trojanOutbound["tls"] as? [String: Any]
        XCTAssertEqual(tls?["enabled"] as? Bool, true)
        XCTAssertEqual(tls?["server_name"] as? String, "trojan.example.com")

        let alpn = tls?["alpn"] as? [String]
        XCTAssertEqual(alpn, ["h2", "http/1.1"])
    }

    func testBuildTrojanWithgRPC() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeTrojangRPCService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let trojanOutbound = findOutbound(in: outbounds, type: "trojan")!

        let transport = trojanOutbound["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "grpc")
        XCTAssertEqual(transport?["service_name"] as? String, "TrojanService")
    }

    func testBuildTrojanWithWebSocket() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeTrojanWebSocketService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let trojanOutbound = findOutbound(in: outbounds, type: "trojan")!

        let transport = trojanOutbound["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/trojan-ws")
    }

    // MARK: - Shadowsocks Protocol Tests

    func testBuildShadowsocksOutbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeShadowsocksService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let ssOutbound = findOutbound(in: outbounds, type: "shadowsocks")!

        XCTAssertEqual(ssOutbound["method"] as? String, "aes-256-gcm")
        XCTAssertEqual(ssOutbound["password"] as? String, "password123")
        // Shadowsocks typically doesn't use TLS wrapper
        XCTAssertNil(ssOutbound["tls"])
    }

    func testBuildShadowsocks2022Cipher() async throws {
        await mockKeychain.preloadCredential("base64key==", ref: "test-cred-ref")
        let service = ConfigFixtures.makeShadowsocks2022Service(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let ssOutbound = findOutbound(in: outbounds, type: "shadowsocks")!

        XCTAssertEqual(ssOutbound["method"] as? String, "2022-blake3-aes-256-gcm")
    }

    func testBuildShadowsocksChaCha20() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeShadowsocksChaChaService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let ssOutbound = findOutbound(in: outbounds, type: "shadowsocks")!

        XCTAssertEqual(ssOutbound["method"] as? String, "chacha20-ietf-poly1305")
    }

    // MARK: - WireGuard Protocol Tests

    func testBuildWireGuardOutbound() async throws {
        await mockKeychain.preloadCredential("WG_PRIVATE_KEY", ref: "test-cred-ref")
        let service = ConfigFixtures.makeWireGuardService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let wgOutbound = findOutbound(in: outbounds, type: "wireguard")!

        XCTAssertEqual(wgOutbound["private_key"] as? String, "WG_PRIVATE_KEY")
        XCTAssertEqual(wgOutbound["peer_public_key"] as? String, "PEER_PUBLIC_KEY")
        XCTAssertEqual(wgOutbound["reserved"] as? [Int], [0, 0, 0])
        XCTAssertEqual(wgOutbound["local_address"] as? [String], ["10.0.0.2/32"])
    }

    func testBuildWireGuardFullConfig() async throws {
        await mockKeychain.preloadCredential("WG_PRIVATE_KEY_FULL", ref: "test-cred-ref")
        let service = ConfigFixtures.makeWireGuardFullService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let wgOutbound = findOutbound(in: outbounds, type: "wireguard")!

        XCTAssertEqual(wgOutbound["private_key"] as? String, "WG_PRIVATE_KEY_FULL")
        XCTAssertEqual(wgOutbound["peer_public_key"] as? String, "Z1XXLsKYkYxuiYjJIkRvtIKFepCYHTgON+GwPq7SOV4=")
        XCTAssertEqual(wgOutbound["pre_shared_key"] as? String, "31aIhAPwktDGpH4JDhA8GNvjFXEf/a6+UaQRyOAiyfM=")
        XCTAssertEqual(wgOutbound["reserved"] as? [Int], [1, 2, 3])
        XCTAssertEqual(wgOutbound["mtu"] as? Int, 1408)

        // Check dual-stack addresses
        let localAddresses = wgOutbound["local_address"] as? [String]
        XCTAssertEqual(localAddresses?.count, 2)
        XCTAssertTrue(localAddresses?.contains("10.0.0.2/32") == true)
        XCTAssertTrue(localAddresses?.contains("fd00::2/128") == true)
    }

    // MARK: - Hysteria2 Protocol Tests

    func testBuildHysteria2Outbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeHysteria2Service(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let hy2Outbound = findOutbound(in: outbounds, type: "hysteria2")!

        XCTAssertEqual(hy2Outbound["password"] as? String, "password123")
        XCTAssertEqual(hy2Outbound["up_mbps"] as? Int, 100)
        XCTAssertEqual(hy2Outbound["down_mbps"] as? Int, 100)

        let obfs = hy2Outbound["obfs"] as? [String: Any]
        XCTAssertEqual(obfs?["type"] as? String, "salamander")
        XCTAssertEqual(obfs?["password"] as? String, "obfspass123")
    }

    func testBuildHysteria2FullConfig() async throws {
        await mockKeychain.preloadCredential("hy2-password", ref: "test-cred-ref")
        let service = ConfigFixtures.makeHysteria2FullService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let hy2Outbound = findOutbound(in: outbounds, type: "hysteria2")!

        XCTAssertEqual(hy2Outbound["password"] as? String, "hy2-password")
        XCTAssertEqual(hy2Outbound["up_mbps"] as? Int, 100)
        XCTAssertEqual(hy2Outbound["down_mbps"] as? Int, 100)

        let obfs = hy2Outbound["obfs"] as? [String: Any]
        XCTAssertEqual(obfs?["type"] as? String, "salamander")
        XCTAssertEqual(obfs?["password"] as? String, "salamander-obfs-password")

        let tls = hy2Outbound["tls"] as? [String: Any]
        XCTAssertEqual(tls?["enabled"] as? Bool, true)
        XCTAssertEqual(tls?["server_name"] as? String, "hy2.example.com")
    }

    func testBuildHysteria2MinimalConfig() async throws {
        await mockKeychain.preloadCredential("hy2-min-password", ref: "test-cred-ref")
        let service = ConfigFixtures.makeHysteria2MinimalService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let hy2Outbound = findOutbound(in: outbounds, type: "hysteria2")!

        XCTAssertEqual(hy2Outbound["password"] as? String, "hy2-min-password")
        // Should not have obfs when not specified
        XCTAssertNil(hy2Outbound["obfs"])
    }

    // MARK: - SOCKS5 Protocol Tests

    func testBuildSOCKS5WithAuth() async throws {
        await mockKeychain.preloadCredential("sockspass", ref: "test-cred-ref")
        let service = ConfigFixtures.makeSOCKS5Service(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let socksOutbound = findOutbound(in: outbounds, type: "socks")!

        XCTAssertEqual(socksOutbound["server"] as? String, "socks.example.com")
        XCTAssertEqual(socksOutbound["server_port"] as? Int, 1080)
        XCTAssertEqual(socksOutbound["username"] as? String, "socksuser")
        XCTAssertEqual(socksOutbound["password"] as? String, "sockspass")
        // SOCKS5 should not have TLS
        XCTAssertNil(socksOutbound["tls"])
    }

    func testBuildSOCKS5NoAuth() async throws {
        let service = ConfigFixtures.makeSOCKS5NoAuthService()
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let socksOutbound = findOutbound(in: outbounds, type: "socks")!

        XCTAssertEqual(socksOutbound["server"] as? String, "socks-noauth.example.com")
        XCTAssertEqual(socksOutbound["server_port"] as? Int, 1080)
        // Should not have username/password
        XCTAssertNil(socksOutbound["username"])
        XCTAssertNil(socksOutbound["password"])
    }

    // MARK: - TLS Configuration Tests

    func testBuildWithInsecureTLS() async throws {
        await mockKeychain.preloadCredential("password", ref: "test-cred-ref")
        let service = ConfigFixtures.makeInsecureTLSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let trojanOutbound = findOutbound(in: outbounds, type: "trojan")!

        let tls = trojanOutbound["tls"] as? [String: Any]
        XCTAssertEqual(tls?["insecure"] as? Bool, true)
    }

    func testBuildWithUTLSChrome() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeUTLSService(credentialRef: "test-cred-ref", fingerprint: "chrome")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let tls = vlessOutbound["tls"] as? [String: Any]
        let utls = tls?["utls"] as? [String: Any]
        XCTAssertEqual(utls?["enabled"] as? Bool, true)
        XCTAssertEqual(utls?["fingerprint"] as? String, "chrome")
    }

    func testBuildWithUTLSFirefox() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeUTLSService(credentialRef: "test-cred-ref", fingerprint: "firefox")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let tls = vlessOutbound["tls"] as? [String: Any]
        let utls = tls?["utls"] as? [String: Any]
        XCTAssertEqual(utls?["fingerprint"] as? String, "firefox")
    }

    func testBuildWithUTLSSafari() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeUTLSService(credentialRef: "test-cred-ref", fingerprint: "safari")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        let tls = vlessOutbound["tls"] as? [String: Any]
        let utls = tls?["utls"] as? [String: Any]
        XCTAssertEqual(utls?["fingerprint"] as? String, "safari")
    }

    // MARK: - Selector and Standard Outbounds

    func testBuildIncludesProxySelector() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let selector = findOutbound(in: outbounds, tag: "proxy")!
        XCTAssertEqual(selector["type"] as? String, "selector")
        XCTAssertNotNil(selector["outbounds"])
    }

    func testBuildIncludesDirectAndBlock() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let direct = findOutbound(in: outbounds, tag: "direct")
        let block = findOutbound(in: outbounds, tag: "block")

        XCTAssertNotNil(direct)
        XCTAssertNotNil(block)
        XCTAssertEqual(direct?["type"] as? String, "direct")
        XCTAssertEqual(block?["type"] as? String, "block")
    }

    // MARK: - Route Tests

    func testBuildFullTunnelMode() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let config = TunnelConfig(mode: .full, rules: [], chain: [])
        let builder = makeBuilder(services: [service], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let route = parsedConfig["route"] as! [String: Any]

        XCTAssertEqual(route["final"] as? String, "proxy")
        XCTAssertEqual(route["auto_detect_interface"] as? Bool, true)
    }

    func testBuildSplitTunnelMode() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let config = ConfigFixtures.makeSplitTunnelConfig()
        let builder = makeBuilder(services: [service], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let route = parsedConfig["route"] as! [String: Any]

        XCTAssertEqual(route["final"] as? String, "direct")

        let rules = route["rules"] as! [[String: Any]]
        // Should have DNS rule + user rules
        XCTAssertGreaterThan(rules.count, 1)
    }

    func testBuildRoutingRules() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")

        let routingRules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy),
            RoutingRule(type: .geoip, value: "CN", outbound: .direct),
            RoutingRule(type: .geosite, value: "category-ads", outbound: .block),
            RoutingRule(type: .processName, value: "Safari", outbound: .direct)
        ]
        let config = TunnelConfig(mode: .split, rules: routingRules, chain: [])
        let builder = makeBuilder(services: [service], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let route = parsedConfig["route"] as! [String: Any]
        let rules = route["rules"] as! [[String: Any]]

        // Find domain rule
        let domainRule = rules.first { ($0["domain"] as? [String])?.contains("example.com") == true }
        XCTAssertNotNil(domainRule)
        XCTAssertEqual(domainRule?["outbound"] as? String, "proxy")

        // Find geoip rule
        let geoipRule = rules.first { ($0["geoip"] as? [String])?.contains("CN") == true }
        XCTAssertNotNil(geoipRule)
        XCTAssertEqual(geoipRule?["outbound"] as? String, "direct")

        // Find geosite rule
        let geositeRule = rules.first { ($0["geosite"] as? [String])?.contains("category-ads") == true }
        XCTAssertNotNil(geositeRule)
        XCTAssertEqual(geositeRule?["outbound"] as? String, "block")

        // Find process rule
        let processRule = rules.first { ($0["process_name"] as? [String])?.contains("Safari") == true }
        XCTAssertNotNil(processRule)
    }

    func testBuildAllRuleTypes() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let config = ConfigFixtures.makeFullRulesTunnelConfig()
        let builder = makeBuilder(services: [service], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let route = parsedConfig["route"] as! [String: Any]
        let rules = route["rules"] as! [[String: Any]]

        // Verify domain rules
        let domainRule = rules.first { ($0["domain"] as? [String])?.contains("exact.example.com") == true }
        XCTAssertNotNil(domainRule, "Should have exact domain rule")

        let domainSuffixRule = rules.first { ($0["domain_suffix"] as? [String])?.contains(".google.com") == true }
        XCTAssertNotNil(domainSuffixRule, "Should have domain suffix rule")

        let domainKeywordRule = rules.first { ($0["domain_keyword"] as? [String])?.contains("facebook") == true }
        XCTAssertNotNil(domainKeywordRule, "Should have domain keyword rule")

        // Verify IP rules
        let ipCidrRule = rules.first { ($0["ip_cidr"] as? [String])?.contains("10.0.0.0/8") == true }
        XCTAssertNotNil(ipCidrRule, "Should have IP CIDR rule")

        // Verify geo rules
        let geoipRule = rules.first { ($0["geoip"] as? [String])?.contains("CN") == true }
        XCTAssertNotNil(geoipRule, "Should have geoip rule")

        let geositeRule = rules.first { ($0["geosite"] as? [String])?.contains("category-ads") == true }
        XCTAssertNotNil(geositeRule, "Should have geosite rule")

        // Verify process rules
        let processNameRule = rules.first { ($0["process_name"] as? [String])?.contains("Safari") == true }
        XCTAssertNotNil(processNameRule, "Should have process name rule")

        let processPathRule = rules.first { ($0["process_path"] as? [String])?.contains("/usr/bin/ssh") == true }
        XCTAssertNotNil(processPathRule, "Should have process path rule")
    }

    // MARK: - Chain Tests

    func testBuildWithChain() async throws {
        await mockKeychain.preloadCredential("uuid1", ref: "cred-1")
        await mockKeychain.preloadCredential("uuid2", ref: "cred-2")

        let service1 = Service(
            name: "First",
            protocol: .vless,
            server: "first.example.com",
            port: 443,
            credentialRef: "cred-1",
            settings: ["tls": .bool(true)]
        )
        let service2 = Service(
            name: "Second",
            protocol: .vless,
            server: "second.example.com",
            port: 443,
            credentialRef: "cred-2",
            settings: ["tls": .bool(true)]
        )

        let config = TunnelConfig(mode: .full, rules: [], chain: [service1.id, service2.id])
        let builder = makeBuilder(services: [service1, service2], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let outbounds = parsedConfig["outbounds"] as! [[String: Any]]

        // Should have chain selector
        let chainOutbound = findOutbound(in: outbounds, tag: "chain")
        XCTAssertNotNil(chainOutbound)
        XCTAssertEqual(chainOutbound?["type"] as? String, "selector")

        // Route final should be chain
        let route = parsedConfig["route"] as! [String: Any]
        XCTAssertEqual(route["final"] as? String, "chain")
    }

    func testBuildChainWithDetour() async throws {
        await mockKeychain.preloadCredential("uuid1", ref: "cred-1")
        await mockKeychain.preloadCredential("uuid2", ref: "cred-2")

        let service1 = Service(
            name: "Entry",
            protocol: .vless,
            server: "entry.example.com",
            port: 443,
            credentialRef: "cred-1",
            settings: ["tls": .bool(true)]
        )
        let service2 = Service(
            name: "Exit",
            protocol: .trojan,
            server: "exit.example.com",
            port: 443,
            credentialRef: "cred-2",
            settings: ["sni": .string("exit.example.com"), "tls": .bool(true)]
        )

        let config = TunnelConfig(mode: .full, rules: [], chain: [service1.id, service2.id])
        let builder = makeBuilder(services: [service1, service2], config: config)

        let json = try await builder.build()
        let parsedConfig = try parseJSON(json)
        let outbounds = parsedConfig["outbounds"] as! [[String: Any]]

        // First service in chain should have detour to second
        let firstOutbound = outbounds.first {
            ($0["tag"] as? String)?.lowercased() == service1.id.uuidString.lowercased()
        }
        XCTAssertNotNil(firstOutbound)
        XCTAssertEqual(
            firstOutbound?["detour"] as? String,
            service2.id.uuidString.lowercased()
        )
    }

    // MARK: - Disabled Services

    func testBuildSkipsDisabledServices() async throws {
        await mockKeychain.preloadCredential("uuid1", ref: "cred-1")
        await mockKeychain.preloadCredential("uuid2", ref: "cred-2")

        var enabledService = ConfigFixtures.makeVLESSService(credentialRef: "cred-1")
        enabledService.isEnabled = true

        var disabledService = ConfigFixtures.makeVMessService(credentialRef: "cred-2")
        disabledService.isEnabled = false

        let builder = makeBuilder(services: [enabledService, disabledService])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        // Should have VLESS but not VMess
        let vlessOutbound = findOutbound(in: outbounds, type: "vless")
        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")

        XCTAssertNotNil(vlessOutbound)
        XCTAssertNil(vmessOutbound)
    }

    // MARK: - Multiple Services

    func testBuildMultipleServices() async throws {
        await mockKeychain.preloadCredential("uuid1", ref: "cred-1")
        await mockKeychain.preloadCredential("password", ref: "cred-2")

        let vless = ConfigFixtures.makeVLESSService(credentialRef: "cred-1")
        let trojan = ConfigFixtures.makeTrojanService(credentialRef: "cred-2")

        let builder = makeBuilder(services: [vless, trojan])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        // Both protocols should be present
        let vlessOutbound = findOutbound(in: outbounds, type: "vless")
        let trojanOutbound = findOutbound(in: outbounds, type: "trojan")

        XCTAssertNotNil(vlessOutbound)
        XCTAssertNotNil(trojanOutbound)

        // Selector should include both
        let selector = findOutbound(in: outbounds, tag: "proxy")!
        let selectorOutbounds = selector["outbounds"] as! [String]
        XCTAssertEqual(selectorOutbounds.count, 2)
    }

    func testBuildAllProtocols() async throws {
        // Preload all credentials
        await mockKeychain.preloadCredential("vless-uuid", ref: "cred-vless")
        await mockKeychain.preloadCredential("vmess-uuid", ref: "cred-vmess")
        await mockKeychain.preloadCredential("trojan-pass", ref: "cred-trojan")
        await mockKeychain.preloadCredential("ss-pass", ref: "cred-ss")
        await mockKeychain.preloadCredential("wg-key", ref: "cred-wg")
        await mockKeychain.preloadCredential("hy2-pass", ref: "cred-hy2")
        await mockKeychain.preloadCredential("socks-pass", ref: "cred-socks")

        let services = [
            ConfigFixtures.makeVLESSService(credentialRef: "cred-vless"),
            ConfigFixtures.makeVMessService(credentialRef: "cred-vmess"),
            ConfigFixtures.makeTrojanService(credentialRef: "cred-trojan"),
            ConfigFixtures.makeShadowsocksService(credentialRef: "cred-ss"),
            ConfigFixtures.makeWireGuardService(credentialRef: "cred-wg"),
            ConfigFixtures.makeHysteria2Service(credentialRef: "cred-hy2"),
            ConfigFixtures.makeSOCKS5Service(credentialRef: "cred-socks")
        ]

        let builder = makeBuilder(services: services)

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        // All protocols should be present
        XCTAssertNotNil(findOutbound(in: outbounds, type: "vless"), "VLESS should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "vmess"), "VMess should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "trojan"), "Trojan should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "shadowsocks"), "Shadowsocks should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "wireguard"), "WireGuard should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "hysteria2"), "Hysteria2 should be present")
        XCTAssertNotNil(findOutbound(in: outbounds, type: "socks"), "SOCKS5 should be present")

        // Selector should include all 7 services
        let selector = findOutbound(in: outbounds, tag: "proxy")!
        let selectorOutbounds = selector["outbounds"] as! [String]
        XCTAssertEqual(selectorOutbounds.count, 7)
    }

    // MARK: - Error Handling Tests

    func testBuildWithMissingTrojanCredentialThrows() async throws {
        // Don't preload credential - should throw
        let service = ConfigFixtures.makeTrojanService(credentialRef: "missing-cred")
        let builder = makeBuilder(services: [service])

        do {
            _ = try await builder.build()
            XCTFail("Should throw error for missing Trojan credential")
        } catch {
            // Expected error
            XCTAssertTrue(error is ConfigBuilderError)
        }
    }

    func testBuildWithMissingShadowsocksCredentialThrows() async throws {
        // Don't preload credential - should throw
        let service = ConfigFixtures.makeShadowsocksService(credentialRef: "missing-cred")
        let builder = makeBuilder(services: [service])

        do {
            _ = try await builder.build()
            XCTFail("Should throw error for missing Shadowsocks credential")
        } catch {
            // Expected error
            XCTAssertTrue(error is ConfigBuilderError)
        }
    }

    func testBuildWithEmptyChainThrows() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "cred")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "cred")

        // Create chain with non-existent service ID
        let config = TunnelConfig(mode: .full, rules: [], chain: [UUID()])
        let builder = makeBuilder(services: [service], config: config)

        do {
            _ = try await builder.build()
            XCTFail("Should throw error for empty chain")
        } catch ConfigBuilderError.emptyChain {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - JSON Output Validation

    func testBuildOutputIsValidJSON() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()

        // Validate it's parseable JSON
        let data = json.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testBuildOutputIsPrettyPrinted() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()

        // Pretty printed JSON should contain newlines
        XCTAssertTrue(json.contains("\n"), "Output should be pretty printed")
    }

    func testBuildOutputHasSortedKeys() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()

        // Keys should be sorted alphabetically
        // "dns" should come before "experimental" which should come before "inbounds"
        let dnsIndex = json.range(of: "\"dns\"")?.lowerBound
        let expIndex = json.range(of: "\"experimental\"")?.lowerBound
        let inboundsIndex = json.range(of: "\"inbounds\"")?.lowerBound

        XCTAssertNotNil(dnsIndex)
        XCTAssertNotNil(expIndex)
        XCTAssertNotNil(inboundsIndex)
        XCTAssertLessThan(dnsIndex!, expIndex!)
        XCTAssertLessThan(expIndex!, inboundsIndex!)
    }

    // MARK: - Transport Tests

    func testBuildWebSocketTransport() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "WS Test",
            protocol: .vmess,
            server: "ws.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "alterId": .int(0),
                "security": .string("auto"),
                "network": .string("ws"),
                "wsPath": .string("/custom-ws-path"),
                "wsHost": .string("custom.host.com"),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        let transport = vmessOutbound["transport"] as! [String: Any]

        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/custom-ws-path")

        let headers = transport["headers"] as? [String: String]
        XCTAssertEqual(headers?["Host"], "custom.host.com")
    }

    func testBuildGRPCTransport() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "gRPC Test",
            protocol: .vless,
            server: "grpc.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "network": .string("grpc"),
                "grpcServiceName": .string("CustomGrpcService"),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!
        let transport = vlessOutbound["transport"] as! [String: Any]

        XCTAssertEqual(transport["type"] as? String, "grpc")
        XCTAssertEqual(transport["service_name"] as? String, "CustomGrpcService")
    }

    func testBuildHTTPTransport() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "HTTP Test",
            protocol: .vmess,
            server: "http.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "alterId": .int(0),
                "security": .string("auto"),
                "network": .string("http"),
                "httpPath": .string("/http-path"),
                "httpHost": .string("http.host.com"),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        let transport = vmessOutbound["transport"] as! [String: Any]

        XCTAssertEqual(transport["type"] as? String, "http")
        XCTAssertEqual(transport["path"] as? String, "/http-path")

        let hosts = transport["host"] as? [String]
        XCTAssertEqual(hosts?.first, "http.host.com")
    }

    func testBuildQUICTransport() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "QUIC Test",
            protocol: .vless,
            server: "quic.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "network": .string("quic"),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!
        let transport = vlessOutbound["transport"] as! [String: Any]

        XCTAssertEqual(transport["type"] as? String, "quic")
    }

    // MARK: - Edge Cases

    func testBuildWithNoTransport() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "No Transport",
            protocol: .vless,
            server: "plain.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "tls": .bool(true)
                // No network setting = TCP default
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        // Should not have transport section for plain TCP
        XCTAssertNil(vlessOutbound["transport"])
    }

    func testBuildWithEmptyFlow() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "No Flow",
            protocol: .vless,
            server: "noflow.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "flow": .string(""),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vlessOutbound = findOutbound(in: outbounds, type: "vless")!

        // Empty flow should not be included
        XCTAssertNil(vlessOutbound["flow"])
    }

    func testBuildWithSpecialCharactersInPath() async throws {
        await mockKeychain.preloadCredential("uuid", ref: "test-cred-ref")
        let service = Service(
            name: "Special Path",
            protocol: .vmess,
            server: "special.example.com",
            port: 443,
            credentialRef: "test-cred-ref",
            settings: [
                "alterId": .int(0),
                "security": .string("auto"),
                "network": .string("ws"),
                "wsPath": .string("/path?ed=2048"),
                "tls": .bool(true)
            ]
        )
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = findOutbound(in: outbounds, type: "vmess")!
        let transport = vmessOutbound["transport"] as! [String: Any]

        XCTAssertEqual(transport["path"] as? String, "/path?ed=2048")
    }
}
