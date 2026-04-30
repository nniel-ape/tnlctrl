//
//  LinkParserTests.swift
//  tnl_ctrl_tests
//
//  Tests for LinkParser covering all supported share-link formats.
//

@testable import tnl_ctrl
import XCTest

@MainActor
final class LinkParserTests: XCTestCase {
    // MARK: - VLESS

    func testParseVLESSFull() {
        let link = ConfigFixtures.URIs.vlessReality
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .vless)
        XCTAssertEqual(result?.service.server, "example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyVLESS-Reality")
        XCTAssertEqual(result?.credential, "550e8400-e29b-41d4-a716-446655440000")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["tls"]?.boolValue, true)
        XCTAssertEqual(settings?["sni"]?.stringValue, "www.microsoft.com")
        XCTAssertEqual(settings?["fingerprint"]?.stringValue, "chrome")
        XCTAssertEqual(settings?["flow"]?.stringValue, "xtls-rprx-vision")
        XCTAssertEqual(settings?["reality"]?.boolValue, true)
        XCTAssertEqual(settings?["realityPublicKey"]?.stringValue, "abc123publickey")
        XCTAssertEqual(settings?["realityShortId"]?.stringValue, "deadbeef")
    }

    func testParseVLESSTLSWithWS() {
        let link = ConfigFixtures.URIs.vlessTLS
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .vless)
        XCTAssertEqual(result?.service.server, "example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyVLESS-TLS")
        XCTAssertEqual(result?.credential, "550e8400-e29b-41d4-a716-446655440000")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["tls"]?.boolValue, true)
        XCTAssertEqual(settings?["sni"]?.stringValue, "example.com")
        XCTAssertEqual(settings?["network"]?.stringValue, "ws")
        XCTAssertEqual(settings?["wsPath"]?.stringValue, "/websocket")
    }

    func testParseVLESSMinimal() {
        let link = "vless://550e8400-e29b-41d4-a716-446655440000@minimal.example.com:8080"
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.server, "minimal.example.com")
        XCTAssertEqual(result?.service.port, 8080)
        XCTAssertEqual(result?.credential, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testParseVLESSInvalidMissingUUID() {
        let link = "vless://@example.com:443"
        XCTAssertNil(LinkParser.parse(link))
    }

    // MARK: - VMess

    func testParseVMess() {
        let link = ConfigFixtures.URIs.vmess
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .vmess)
        XCTAssertEqual(result?.service.server, "vmess.example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyVMess")
        XCTAssertEqual(result?.credential, "550e8400-e29b-41d4-a716-446655440000")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["tls"]?.boolValue, true)
        XCTAssertEqual(settings?["security"]?.stringValue, "auto")
        XCTAssertEqual(settings?["alterId"]?.intValue, 0)
        XCTAssertEqual(settings?["network"]?.stringValue, "ws")
        XCTAssertEqual(settings?["wsPath"]?.stringValue, "/v2ray")
        XCTAssertEqual(settings?["wsHost"]?.stringValue, "vmess.example.com")
    }

    func testParseVMessInvalidBase64() {
        let link = ConfigFixtures.URIs.invalidBase64
        XCTAssertNil(LinkParser.parse(link))
    }

    // MARK: - Trojan

    func testParseTrojan() {
        let link = ConfigFixtures.URIs.trojan
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .trojan)
        XCTAssertEqual(result?.service.server, "trojan.example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyTrojan")
        XCTAssertEqual(result?.credential, "password123")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["sni"]?.stringValue, "trojan.example.com")
        XCTAssertEqual(settings?["alpn"]?.stringValue, "h2,http/1.1")
    }

    func testParseTrojanMinimal() {
        let link = "trojan://pass@minimal.example.com:8443#MinimalTrojan"
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.server, "minimal.example.com")
        XCTAssertEqual(result?.service.port, 8443)
        XCTAssertEqual(result?.credential, "pass")
    }

    func testParseTrojanInvalidMissingPassword() {
        let link = "trojan://@example.com:443"
        XCTAssertNil(LinkParser.parse(link))
    }

    // MARK: - Shadowsocks

    func testParseShadowsocksSIP002() {
        let link = ConfigFixtures.URIs.shadowsocks
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .shadowsocks)
        XCTAssertEqual(result?.service.server, "ss.example.com")
        XCTAssertEqual(result?.service.port, 8388)
        XCTAssertEqual(result?.service.name, "MyShadowsocks")
        XCTAssertEqual(result?.credential, "password123")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["method"]?.stringValue, "aes-256-gcm")
    }

    func testParseShadowsocksLegacyBase64Full() {
        // Older format: ss://BASE64(method:password@host:port)#name
        let full = "aes-256-gcm:password123@ss.example.com:8388".data(using: .utf8)!.base64EncodedString()
        let link = "ss://\(full)#LegacySS"
        let result = LinkParser.parse(link)

        // This non-standard format is not supported; parser should return nil
        XCTAssertNil(result)
    }

    func testParseShadowsocksPlain() {
        let link = "ss://aes-128-gcm:plainpass@ss2.example.com:8389#PlainSS"
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.server, "ss2.example.com")
        XCTAssertEqual(result?.service.port, 8389)
        XCTAssertEqual(result?.credential, "plainpass")
        XCTAssertEqual(result?.service.settings["method"]?.stringValue, "aes-128-gcm")
    }

    func testParseShadowsocksWithPlugin() {
        let link = "ss://YWVzLTI1Ni1nY206cGFzcw==@plugin.example.com:8388/?plugin=obfs-local%3Bobfs%3Dhttp%3Bobfs-host%3Dexample.com#SS-Plugin"
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.settings["plugin"]?.stringValue, "obfs-local")
        XCTAssertEqual(result?.service.settings["pluginOpts"]?.stringValue, "obfs=http;obfs-host=example.com")
    }

    // MARK: - SOCKS5

    func testParseSOCKS5WithAuth() {
        let link = ConfigFixtures.URIs.socks5WithAuth
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .socks5)
        XCTAssertEqual(result?.service.server, "socks.example.com")
        XCTAssertEqual(result?.service.port, 1080)
        XCTAssertEqual(result?.service.name, "MySOCKS5")
        XCTAssertEqual(result?.service.settings["username"]?.stringValue, "user")
        XCTAssertEqual(result?.credential, "pass123")
    }

    func testParseSOCKS5NoAuth() {
        let link = ConfigFixtures.URIs.socks5NoAuth
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .socks5)
        XCTAssertEqual(result?.service.server, "socks.example.com")
        XCTAssertEqual(result?.service.port, 1080)
        XCTAssertEqual(result?.service.name, "MySOCKS5-NoAuth")
        XCTAssertNil(result?.credential)
        XCTAssertNil(result?.service.settings["username"])
    }

    // MARK: - Hysteria2

    func testParseHysteria2Full() {
        let link = ConfigFixtures.URIs.hysteria2
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.protocol, .hysteria2)
        XCTAssertEqual(result?.service.server, "hy2.example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyHysteria2")
        XCTAssertEqual(result?.credential, "password123")

        let settings = result?.service.settings
        XCTAssertEqual(settings?["tls"]?.boolValue, true)
        XCTAssertEqual(settings?["sni"]?.stringValue, "hy2.example.com")
        XCTAssertEqual(settings?["obfs"]?.stringValue, "salamander")
    }

    func testParseHysteria2Minimal() {
        let link = ConfigFixtures.URIs.hysteria2Minimal
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.server, "hy2.example.com")
        XCTAssertEqual(result?.service.port, 443)
        XCTAssertEqual(result?.service.name, "MyHysteria2-Minimal")
        XCTAssertEqual(result?.credential, "password123")
        XCTAssertEqual(result?.service.settings["tls"]?.boolValue, true)
    }

    func testParseHysteria2WithBandwidth() {
        let link = "hysteria2://pass@bw.example.com:443?sni=bw.example.com&up=50&down=100#BW"
        let result = LinkParser.parse(link)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.service.settings["up"]?.stringValue, "50")
        XCTAssertEqual(result?.service.settings["down"]?.stringValue, "100")
    }

    // MARK: - Batch Parsing

    func testParseBatchMixed() {
        let input = """
        vless://uuid1@server1.com:443?security=tls#Server1
        invalid-line-here
        trojan://pass@server2.com:443#Server2
        """

        let (results, errors) = LinkParser.parseBatch(input)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(results[0].service.protocol, .vless)
        XCTAssertEqual(results[1].service.protocol, .trojan)
    }

    func testParseBatchEmpty() {
        let (results, errors) = LinkParser.parseBatch("")
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(errors.isEmpty)
    }

    func testParseBatchAllInvalid() {
        let input = """
        not-a-link
        also-not-valid
        """

        let (results, errors) = LinkParser.parseBatch(input)
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(errors.count, 2)
    }

    func testParseBatchSkipsEmptyLines() {
        let input = "\nss://aes-256-gcm:pass@ss.com:8388#SS\n"

        let (results, errors) = LinkParser.parseBatch(input)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Edge Cases

    func testParseEmptyString() {
        XCTAssertNil(LinkParser.parse(""))
    }

    func testParseWhitespaceOnly() {
        XCTAssertNil(LinkParser.parse("   \n\t  "))
    }

    func testParseUnsupportedScheme() {
        XCTAssertNil(LinkParser.parse("unknown://example.com:443"))
    }

    func testParseMissingHost() {
        XCTAssertNil(LinkParser.parse("vless://uuid@:443"))
    }

    func testParseNamePercentDecoding() {
        let link = "vless://uuid@example.com:443#My%20Server%20Name"
        let result = LinkParser.parse(link)
        XCTAssertEqual(result?.service.name, "My Server Name")
    }
}
