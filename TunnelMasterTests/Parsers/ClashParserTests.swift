//
//  ClashParserTests.swift
//  TunnelMasterTests
//

import XCTest
@testable import TunnelMaster

@MainActor
final class ClashParserTests: XCTestCase {
    var mockKeychain: MockKeychainManager!
    var parser: ClashParser!

    override func setUp() async throws {
        mockKeychain = MockKeychainManager()
        parser = ClashParser(keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        await mockKeychain.reset()
        mockKeychain = nil
        parser = nil
    }

    // MARK: - canImport Tests

    func testCanImportClashConfig() {
        let data = ConfigFixtures.Clash.multiLineProxy.data(using: .utf8)!
        XCTAssertTrue(parser.canImport(data: data))
    }

    func testCannotImportNoProxiesSection() {
        let data = ConfigFixtures.Clash.noProxiesSection.data(using: .utf8)!
        XCTAssertFalse(parser.canImport(data: data))
    }

    // MARK: - Multi-line Proxy Format

    func testParseMultiLineProxy() async throws {
        let data = ConfigFixtures.Clash.multiLineProxy.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyVLESS")
        XCTAssertEqual(service.protocol, .vless)
        XCTAssertEqual(service.server, "example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["flow"]?.stringValue, "xtls-rprx-vision")
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "example.com")
        XCTAssertEqual(service.settings["tls_insecure"]?.boolValue, false)

        // Verify credential stored
        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedUUID = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedUUID, "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - Inline Proxy Format

    func testParseInlineProxy() async throws {
        let data = ConfigFixtures.Clash.inlineProxy.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyVMess")
        XCTAssertEqual(service.protocol, .vmess)
        XCTAssertEqual(service.server, "vmess.example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["alter_id"]?.intValue, 0)
        XCTAssertEqual(service.settings["security"]?.stringValue, "auto")
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
    }

    // MARK: - Multiple Proxies

    func testParseMultipleProxies() async throws {
        let data = ConfigFixtures.Clash.multipleProxies.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 2, "Expected 2 services, got \(services.count)")
        guard services.count >= 2 else {
            XCTFail("Not enough services parsed")
            return
        }
        XCTAssertEqual(services[0].name, "Server1")
        XCTAssertEqual(services[0].protocol, .vless)
        XCTAssertEqual(services[1].name, "Server2")
        XCTAssertEqual(services[1].protocol, .trojan)
    }

    // MARK: - Shadowsocks

    func testParseShadowsocksProxy() async throws {
        let data = ConfigFixtures.Clash.shadowsocksProxy.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MySS")
        XCTAssertEqual(service.protocol, .shadowsocks)
        XCTAssertEqual(service.server, "ss.example.com")
        XCTAssertEqual(service.port, 8388)
        XCTAssertEqual(service.settings["method"]?.stringValue, "aes-256-gcm")

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    // MARK: - Empty/Missing Proxies

    func testParseNoProxiesReturnsEmpty() async throws {
        let data = ConfigFixtures.Clash.noProxiesSection.data(using: .utf8)!
        let services = try await parser.parse(data: data)
        XCTAssertTrue(services.isEmpty)
    }

    // MARK: - Field Variations

    func testParseKebabCaseFields() async throws {
        let yaml = """
        proxies:
          - name: TestProxy
            type: vless
            server: example.com
            port: 443
            uuid: test-uuid
            skip-cert-verify: true
            ws-path: /websocket
        """
        let data = yaml.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.settings["tls_insecure"]?.boolValue, true)
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/websocket")
    }

    func testParseCamelCaseFields() async throws {
        let yaml = """
        proxies:
          - name: TestProxy
            type: wireguard
            server: wg.example.com
            port: 51820
            privateKey: WG_PRIVATE_KEY
            publicKey: WG_PUBLIC_KEY
        """
        let data = yaml.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.protocol, .wireguard)
        XCTAssertEqual(service.settings["peer_public_key"]?.stringValue, "WG_PUBLIC_KEY")
    }

    func testParseQuotedValues() async throws {
        let yaml = """
        proxies:
          - name: "Quoted Name"
            type: vless
            server: 'example.com'
            port: 443
            uuid: "test-uuid"
        """
        let data = yaml.data(using: .utf8)!
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.name, "Quoted Name")
        XCTAssertEqual(service.server, "example.com")
    }
}
