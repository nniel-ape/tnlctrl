//
//  V2RayParserTests.swift
//  TunnelMasterTests
//

@testable import TunnelMaster
import XCTest

@MainActor
final class V2RayParserTests: XCTestCase {
    var mockKeychain: MockKeychainManager!
    var parser: V2RayParser!

    override func setUp() async throws {
        mockKeychain = MockKeychainManager()
        parser = V2RayParser(keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        await mockKeychain.reset()
        mockKeychain = nil
        parser = nil
    }

    // MARK: - canImport Tests

    func testCanImportV2RayConfig() throws {
        let data = try XCTUnwrap(ConfigFixtures.V2Ray.vlessVnext.data(using: .utf8))
        XCTAssertTrue(parser.canImport(data: data))
    }

    func testCannotImportSingBoxConfig() throws {
        // sing-box doesn't have "protocol" field in outbounds
        let data = try XCTUnwrap(ConfigFixtures.SingBox.vlessOutbound.data(using: .utf8))
        XCTAssertFalse(parser.canImport(data: data))
    }

    func testCannotImportInvalidJSON() throws {
        let data = try XCTUnwrap(ConfigFixtures.SingBox.invalidJSON.data(using: .utf8))
        XCTAssertFalse(parser.canImport(data: data))
    }

    // MARK: - VLESS Parsing

    func testParseVLESSVnext() async throws {
        let data = try XCTUnwrap(ConfigFixtures.V2Ray.vlessVnext.data(using: .utf8))
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
        XCTAssertEqual(service.settings["encryption"]?.stringValue, "none")

        // Reality settings from stream
        XCTAssertEqual(service.settings["reality_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["reality_public_key"]?.stringValue, "abc123publickey")
        XCTAssertEqual(service.settings["reality_short_id"]?.stringValue, "deadbeef")
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "www.microsoft.com")

        // Verify credential stored
        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedUUID = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedUUID, "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - VMess Parsing

    func testParseVMessVnext() async throws {
        let data = try XCTUnwrap(ConfigFixtures.V2Ray.vmessVnext.data(using: .utf8))
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

        // Stream settings
        XCTAssertEqual(service.settings["transport_type"]?.stringValue, "ws")
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)
        XCTAssertEqual(service.settings["tls_server_name"]?.stringValue, "vmess.example.com")

        // WebSocket settings
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/websocket")
        XCTAssertEqual(service.settings["transport_host"]?.stringValue, "vmess.example.com")
    }

    // MARK: - Trojan Parsing

    func testParseTrojanServers() async throws {
        let data = try XCTUnwrap(ConfigFixtures.V2Ray.trojanServers.data(using: .utf8))
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
        XCTAssertEqual(service.settings["tls_enabled"]?.boolValue, true)

        let credentialRef = try XCTUnwrap(service.credentialRef)
        let storedPassword = try await mockKeychain.get(credentialRef)
        XCTAssertEqual(storedPassword, "password123")
    }

    // MARK: - Stream Settings Parsing

    func testParseGRPCSettings() async throws {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "vless",
                    "tag": "grpc-test",
                    "settings": {
                        "vnext": [
                            {
                                "address": "example.com",
                                "port": 443,
                                "users": [{"id": "uuid", "flow": ""}]
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": "grpc",
                        "security": "tls",
                        "grpcSettings": {
                            "serviceName": "my-grpc-service"
                        }
                    }
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.settings["transport_type"]?.stringValue, "grpc")
        XCTAssertEqual(service.settings["transport_service_name"]?.stringValue, "my-grpc-service")
    }

    func testParseHTTP2Settings() async throws {
        let json = """
        {
            "outbounds": [
                {
                    "protocol": "vless",
                    "tag": "h2-test",
                    "settings": {
                        "vnext": [
                            {
                                "address": "example.com",
                                "port": 443,
                                "users": [{"id": "uuid"}]
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": "http",
                        "security": "tls",
                        "httpSettings": {
                            "path": "/h2path",
                            "host": ["example.com"]
                        }
                    }
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let services = try await parser.parse(data: data)

        XCTAssertEqual(services.count, 1, "Expected 1 service, got \(services.count)")
        guard let service = services.first else {
            XCTFail("No services parsed")
            return
        }
        XCTAssertEqual(service.settings["transport_path"]?.stringValue, "/h2path")
        XCTAssertEqual(service.settings["transport_host"]?.stringValue, "example.com")
    }

    // MARK: - Error Cases

    func testParseMissingOutbounds() async throws {
        let json = """
        {
            "inbounds": []
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
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

    func testParseInvalidJSON() async {
        let data = "{ invalid }".data(using: .utf8)!
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
}
