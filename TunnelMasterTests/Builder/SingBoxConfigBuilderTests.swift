//
//  SingBoxConfigBuilderTests.swift
//  TunnelMasterTests
//

import XCTest
@testable import TunnelMaster

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

    // MARK: - Basic Structure Tests

    func testBuildContainsAllSections() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)

        XCTAssertNotNil(config["log"])
        XCTAssertNotNil(config["dns"])
        XCTAssertNotNil(config["inbounds"])
        XCTAssertNotNil(config["outbounds"])
        XCTAssertNotNil(config["route"])
        XCTAssertNotNil(config["experimental"])
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
        XCTAssertEqual(tun["interface_name"] as? String, "utun199")
        XCTAssertEqual(tun["auto_route"] as? Bool, true)
        XCTAssertEqual(tun["strict_route"] as? Bool, true)
    }

    // MARK: - Protocol-Specific Tests

    func testBuildVLESSOutbound() async throws {
        await mockKeychain.preloadCredential("550e8400-e29b-41d4-a716-446655440000", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        // Find the VLESS outbound (not selector/direct/block)
        let vlessOutbound = outbounds.first { $0["type"] as? String == "vless" }!

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

    func testBuildVMessOutbound() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVMessService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let vmessOutbound = outbounds.first { $0["type"] as? String == "vmess" }!

        XCTAssertEqual(vmessOutbound["type"] as? String, "vmess")
        XCTAssertEqual(vmessOutbound["uuid"] as? String, "test-uuid")
        XCTAssertEqual(vmessOutbound["alter_id"] as? Int, 0)
        XCTAssertEqual(vmessOutbound["security"] as? String, "auto")

        // WebSocket transport
        let transport = vmessOutbound["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/websocket")
    }

    func testBuildTrojanOutbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeTrojanService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let trojanOutbound = outbounds.first { $0["type"] as? String == "trojan" }!

        XCTAssertEqual(trojanOutbound["password"] as? String, "password123")
        XCTAssertNotNil(trojanOutbound["tls"])
    }

    func testBuildShadowsocksOutbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeShadowsocksService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let ssOutbound = outbounds.first { $0["type"] as? String == "shadowsocks" }!

        XCTAssertEqual(ssOutbound["method"] as? String, "aes-256-gcm")
        XCTAssertEqual(ssOutbound["password"] as? String, "password123")
        // Shadowsocks typically doesn't use TLS wrapper
        XCTAssertNil(ssOutbound["tls"])
    }

    func testBuildWireGuardOutbound() async throws {
        await mockKeychain.preloadCredential("WG_PRIVATE_KEY", ref: "test-cred-ref")
        let service = ConfigFixtures.makeWireGuardService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let wgOutbound = outbounds.first { $0["type"] as? String == "wireguard" }!

        XCTAssertEqual(wgOutbound["private_key"] as? String, "WG_PRIVATE_KEY")
        XCTAssertEqual(wgOutbound["peer_public_key"] as? String, "PEER_PUBLIC_KEY")
        XCTAssertEqual(wgOutbound["reserved"] as? [Int], [0, 0, 0])
        XCTAssertEqual(wgOutbound["local_address"] as? [String], ["10.0.0.2/32"])
    }

    func testBuildHysteria2Outbound() async throws {
        await mockKeychain.preloadCredential("password123", ref: "test-cred-ref")
        let service = ConfigFixtures.makeHysteria2Service(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let hy2Outbound = outbounds.first { $0["type"] as? String == "hysteria2" }!

        XCTAssertEqual(hy2Outbound["password"] as? String, "password123")
        XCTAssertEqual(hy2Outbound["up_mbps"] as? Int, 100)
        XCTAssertEqual(hy2Outbound["down_mbps"] as? Int, 100)

        let obfs = hy2Outbound["obfs"] as? [String: Any]
        XCTAssertEqual(obfs?["type"] as? String, "salamander")
        XCTAssertEqual(obfs?["password"] as? String, "obfspass123")
    }

    // MARK: - Selector and Standard Outbounds

    func testBuildIncludesProxySelector() async throws {
        await mockKeychain.preloadCredential("test-uuid", ref: "test-cred-ref")
        let service = ConfigFixtures.makeVLESSService(credentialRef: "test-cred-ref")
        let builder = makeBuilder(services: [service])

        let json = try await builder.build()
        let config = try parseJSON(json)
        let outbounds = config["outbounds"] as! [[String: Any]]

        let selector = outbounds.first { $0["tag"] as? String == "proxy" }!
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

        let direct = outbounds.first { $0["tag"] as? String == "direct" }
        let block = outbounds.first { $0["tag"] as? String == "block" }

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
        let chainOutbound = outbounds.first { $0["tag"] as? String == "chain" }
        XCTAssertNotNil(chainOutbound)
        XCTAssertEqual(chainOutbound?["type"] as? String, "selector")

        // Route final should be chain
        let route = parsedConfig["route"] as! [String: Any]
        XCTAssertEqual(route["final"] as? String, "chain")
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
        let vlessOutbound = outbounds.first { $0["type"] as? String == "vless" }
        let vmessOutbound = outbounds.first { $0["type"] as? String == "vmess" }

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
        let vlessOutbound = outbounds.first { $0["type"] as? String == "vless" }
        let trojanOutbound = outbounds.first { $0["type"] as? String == "trojan" }

        XCTAssertNotNil(vlessOutbound)
        XCTAssertNotNil(trojanOutbound)

        // Selector should include both
        let selector = outbounds.first { $0["tag"] as? String == "proxy" }!
        let selectorOutbounds = selector["outbounds"] as! [String]
        XCTAssertEqual(selectorOutbounds.count, 2)
    }
}
