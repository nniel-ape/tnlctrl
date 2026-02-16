//
//  SingBoxParserTests.swift
//  TunnelMasterTests
//

@testable import TunnelMaster
import XCTest

@MainActor
final class SingBoxParserTests: XCTestCase {
    var mockKeychain: MockKeychainManager!
    var parser: SingBoxParser!

    override func setUp() async throws {
        mockKeychain = MockKeychainManager()
        parser = SingBoxParser(keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        await mockKeychain.reset()
        mockKeychain = nil
        parser = nil
    }

    // MARK: - canImport Tests

    func testCanImportValidSingBoxConfig() throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.vlessOutbound.data(using: .utf8))
        XCTAssertTrue(parser.canImport(data: data))
    }

    func testCannotImportMissingOutbounds() throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.missingOutbounds.data(using: .utf8))
        XCTAssertFalse(parser.canImport(data: data))
    }

    func testCannotImportInvalidJSON() throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.invalidJSON.data(using: .utf8))
        XCTAssertFalse(parser.canImport(data: data))
    }

    // MARK: - VLESS Parsing

    func testParseVLESSOutbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.vlessOutbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "vless-out")
        XCTAssertEqual(service.protocol, .vless)
        XCTAssertEqual(service.server, "example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["flow"]?.stringValue, "xtls-rprx-vision")

        // TLS settings
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "example.com")
        XCTAssertEqual(service.settings["tls_insecure"]?.boolValue, false)

        // Reality settings
        XCTAssertEqual(service.settings["reality_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["reality_public_key"]?.stringValue, "abc123publickey")
        XCTAssertEqual(service.settings["reality_short_id"]?.stringValue, "deadbeef")

        // Verify credential stored
        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedUUID = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedUUID, "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - VMess Parsing

    func testParseVMessOutbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.vmessOutbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "vmess-out")
        XCTAssertEqual(service.protocol, .vmess)
        XCTAssertEqual(service.server, "vmess.example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["alter_id"]?.intValue, 0)
        XCTAssertEqual(service.settings["security"]?.stringValue, "auto")

        // Transport settings
        XCTAssertEqual(service.settings["transport_type"]?.stringValue, "ws")
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/websocket")
    }

    // MARK: - Trojan Parsing

    func testParseTrojanOutbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.trojanOutbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "trojan-out")
        XCTAssertEqual(service.protocol, .trojan)
        XCTAssertEqual(service.server, "trojan.example.com")
        XCTAssertEqual(service.port, 443)

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    // MARK: - Shadowsocks Parsing

    func testParseShadowsocksOutbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.shadowsocksOutbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "ss-out")
        XCTAssertEqual(service.protocol, .shadowsocks)
        XCTAssertEqual(service.settings["method"]?.stringValue, "aes-256-gcm")
    }

    // MARK: - WireGuard Parsing

    func testParseWireGuardOutbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.wireguardOutbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "wg-out")
        XCTAssertEqual(service.protocol, .wireguard)
        XCTAssertEqual(service.server, "wg.example.com")
        XCTAssertEqual(service.port, 51820)
        XCTAssertEqual(service.settings["peer_public_key"]?.stringValue, "WG_PEER_PUBLIC_KEY_BASE64")
    }

    // MARK: - Hysteria2 Parsing

    func testParseHysteria2Outbound() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.hysteria2Outbound.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "hy2-out")
        XCTAssertEqual(service.protocol, .hysteria2)
        XCTAssertEqual(service.server, "hy2.example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["obfs_type"]?.stringValue, "salamander")
        XCTAssertEqual(service.settings["obfs_password"]?.stringValue, "obfspass123")
    }

    // MARK: - Multiple Outbounds

    func testParseMultipleOutbounds() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.multipleOutbounds.data(using: .utf8))
        let services = try await parser.parse(data: data)

        // Should only parse proxy outbounds (vless, vmess), skip direct/block
        XCTAssertEqual(services.count, 2, "Expected 2 services, got \(services.count)")
        guard services.count >= 2 else {
            XCTFail("Not enough services parsed")
            return
        }
        XCTAssertEqual(services[0].name, "vless-1")
        XCTAssertEqual(services[1].name, "vmess-1")
    }

    // MARK: - Error Cases

    func testParseInvalidJSON() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.invalidJSON.data(using: .utf8))
        do {
            _ = try await parser.parse(data: data)
            XCTFail("Expected error for invalid JSON")
        } catch let error as ConfigImportError {
            if case .invalidFormat = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testParseMissingOutbounds() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.missingOutbounds.data(using: .utf8))
        do {
            _ = try await parser.parse(data: data)
            XCTFail("Expected error for missing outbounds")
        } catch let error as ConfigImportError {
            if case .missingRequiredField = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testParseEmptyOutbounds() async throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.emptyOutbounds.data(using: .utf8))
        let services = try await parser.parse(data: data)
        XCTAssertTrue(services.isEmpty)
    }
}
