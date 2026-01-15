//
//  URIParserTests.swift
//  TunnelMasterTests
//

@testable import TunnelMaster
import XCTest

@MainActor
final class URIParserTests: XCTestCase {
    var mockKeychain: MockKeychainManager!
    var parser: URIParser!

    override func setUp() async throws {
        mockKeychain = MockKeychainManager()
        parser = URIParser(keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        await mockKeychain.reset()
        mockKeychain = nil
        parser = nil
    }

    // MARK: - canImport Tests

    func testCanImportVLESS() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.vlessReality))
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.vlessTLS))
    }

    func testCanImportVMess() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.vmess))
    }

    func testCanImportTrojan() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.trojan))
    }

    func testCanImportShadowsocks() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.shadowsocks))
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.shadowsocksLegacy))
    }

    func testCanImportSOCKS5() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.socks5WithAuth))
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.socks5NoAuth))
    }

    func testCanImportHysteria2() {
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.hysteria2))
        XCTAssertTrue(parser.canImport(text: ConfigFixtures.URIs.hysteria2Minimal))
    }

    func testCannotImportUnsupportedScheme() {
        XCTAssertFalse(parser.canImport(text: ConfigFixtures.URIs.unsupportedScheme))
        XCTAssertFalse(parser.canImport(text: "just some text"))
    }

    // MARK: - VLESS Parsing Tests

    func testParseVLESSWithReality() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.vlessReality)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyVLESS-Reality")
        XCTAssertEqual(service.protocol, .vless)
        XCTAssertEqual(service.server, "example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertNotNil(service.credentialRef)

        // Verify settings
        XCTAssertEqual(service.settings["flow"]?.stringValue, "xtls-rprx-vision")
        XCTAssertEqual(service.settings["reality_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["reality_public_key"]?.stringValue, "abc123publickey")
        XCTAssertEqual(service.settings["reality_short_id"]?.stringValue, "deadbeef")
        XCTAssertEqual(service.settings["fingerprint"]?.stringValue, "chrome")

        // Verify credential was stored
        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedUUID = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedUUID, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testParseVLESSWithTLS() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.vlessTLS)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyVLESS-TLS")
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "example.com")
        XCTAssertEqual(service.settings["transport_type"]?.stringValue, "ws")
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/websocket")
    }

    // MARK: - VMess Parsing Tests

    func testParseVMess() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.vmess)

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
        XCTAssertEqual(service.settings["transport_type"]?.stringValue, "ws")
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/v2ray")
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
    }

    func testParseVMessInvalidBase64() async {
        do {
            _ = try await parser.parse(text: ConfigFixtures.URIs.invalidBase64)
            XCTFail("Expected error for invalid base64")
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

    // MARK: - Trojan Parsing Tests

    func testParseTrojan() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.trojan)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyTrojan")
        XCTAssertEqual(service.protocol, .trojan)
        XCTAssertEqual(service.server, "trojan.example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "trojan.example.com")

        // Verify password stored
        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    // MARK: - Shadowsocks Parsing Tests

    func testParseShadowsocksSIP002() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.shadowsocks)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyShadowsocks")
        XCTAssertEqual(service.protocol, .shadowsocks)
        XCTAssertEqual(service.server, "ss.example.com")
        XCTAssertEqual(service.port, 8388)
        XCTAssertEqual(service.settings["method"]?.stringValue, "aes-256-gcm")

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    func testParseShadowsocksLegacy() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.shadowsocksLegacy)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyShadowsocks-Legacy")
        XCTAssertEqual(service.protocol, .shadowsocks)
    }

    // MARK: - SOCKS5 Parsing Tests

    func testParseSOCKS5WithAuth() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.socks5WithAuth)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MySOCKS5")
        XCTAssertEqual(service.protocol, .socks5)
        XCTAssertEqual(service.server, "socks.example.com")
        XCTAssertEqual(service.port, 1080)
        XCTAssertEqual(service.settings["username"]?.stringValue, "user")
        XCTAssertNotNil(service.credentialRef)

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "pass123")
    }

    func testParseSOCKS5NoAuth() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.socks5NoAuth)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MySOCKS5-NoAuth")
        XCTAssertEqual(service.protocol, .socks5)
        XCTAssertNil(service.credentialRef)
        XCTAssertNil(service.settings["username"])
    }

    // MARK: - Hysteria2 Parsing Tests

    func testParseHysteria2Full() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.hysteria2)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyHysteria2")
        XCTAssertEqual(service.protocol, .hysteria2)
        XCTAssertEqual(service.server, "hy2.example.com")
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "hy2.example.com")
        XCTAssertEqual(service.settings["tls_insecure"]?.boolValue, false)
        XCTAssertEqual(service.settings["obfs_type"]?.stringValue, "salamander")
        XCTAssertEqual(service.settings["obfs"]?.stringValue, "obfspass123")

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    func testParseHysteria2Minimal() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.hysteria2Minimal)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }

        XCTAssertEqual(service.name, "MyHysteria2-Minimal")
        XCTAssertEqual(service.protocol, .hysteria2)
        XCTAssertEqual(service.port, 443)
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
    }

    // MARK: - Multiple URIs Tests

    func testParseMultipleURIs() async throws {
        let services = try await parser.parse(text: ConfigFixtures.URIs.multipleURIs)

        XCTAssertEqual(services.count, 2, "Expected 2 services, got \(services.count)")
        guard services.count >= 2 else {
            XCTFail("Not enough services parsed")
            return
        }
        XCTAssertEqual(services[0].name, "Server1")
        XCTAssertEqual(services[1].name, "Server2")
        XCTAssertEqual(services[0].server, "server1.example.com")
        XCTAssertEqual(services[1].server, "server2.example.com")
    }

    // MARK: - Error Cases

    func testParseInvalidFormat() async {
        do {
            _ = try await parser.parse(text: ConfigFixtures.URIs.invalidFormat)
            XCTFail("Expected error for invalid format")
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

    func testParseUnsupportedSchemeReturnsEmpty() async throws {
        // Unsupported schemes should return empty array, not throw
        let services = try await parser.parse(text: ConfigFixtures.URIs.unsupportedScheme)
        XCTAssertTrue(services.isEmpty)
    }

    // MARK: - Default Port Tests

    func testDefaultPortVLESS() async throws {
        let uri = "vless://uuid@example.com?security=tls#Test"
        let services = try await parser.parse(text: uri)
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.port, 443)
    }

    func testDefaultPortShadowsocks() async throws {
        let userInfo = "aes-256-gcm:pass".data(using: .utf8)!.base64EncodedString()
        let uri = "ss://\(userInfo)@example.com#Test"
        let services = try await parser.parse(text: uri)
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.port, 8388)
    }

    func testDefaultPortSOCKS5() async throws {
        let uri = "socks5://example.com#Test"
        let services = try await parser.parse(text: uri)
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.port, 1080)
    }
}
