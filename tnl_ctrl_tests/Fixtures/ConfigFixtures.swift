//
//  ConfigFixtures.swift
//  tnl_ctrl_tests
//
//  Test data constants using fresh 2024-2025 protocol schemes
//

import Foundation
@testable import tnl_ctrl

// swiftlint:disable line_length

enum ConfigFixtures {
    // MARK: - URI Schemes

    enum URIs {
        /// VLESS with Reality (2024+ scheme)
        static let vlessReality = "vless://550e8400-e29b-41d4-a716-446655440000@example.com:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=abc123publickey&sid=deadbeef&type=tcp#MyVLESS-Reality"

        /// VLESS with TLS
        static let vlessTLS = "vless://550e8400-e29b-41d4-a716-446655440000@example.com:443?encryption=none&security=tls&sni=example.com&type=ws&path=%2Fwebsocket#MyVLESS-TLS"

        /// VMess (v2rayN format, base64 encoded JSON)
        static let vmess: String = {
            let json: [String: Any] = [
                "v": "2",
                "ps": "MyVMess",
                "add": "vmess.example.com",
                "port": 443,
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "aid": 0,
                "scy": "auto",
                "net": "ws",
                "path": "/v2ray",
                "host": "vmess.example.com",
                "tls": "tls"
            ]
            let data = try! JSONSerialization.data(withJSONObject: json)
            return "vmess://" + data.base64EncodedString()
        }()

        /// Trojan
        static let trojan = "trojan://password123@trojan.example.com:443?sni=trojan.example.com&alpn=h2%2Chttp%2F1.1#MyTrojan"

        /// Shadowsocks (SIP002 format)
        static let shadowsocks: String = {
            // aes-256-gcm:password123
            let userInfo = "aes-256-gcm:password123".data(using: .utf8)!.base64EncodedString()
            return "ss://\(userInfo)@ss.example.com:8388#MyShadowsocks"
        }()

        /// Shadowsocks (legacy format)
        static let shadowsocksLegacy: String = {
            // method:password@host:port
            let full = "aes-256-gcm:password123@ss.example.com:8388".data(using: .utf8)!.base64EncodedString()
            return "ss://\(full)#MyShadowsocks-Legacy"
        }()

        /// SOCKS5 with auth
        static let socks5WithAuth = "socks5://user:pass123@socks.example.com:1080#MySOCKS5"

        /// SOCKS5 without auth
        static let socks5NoAuth = "socks5://socks.example.com:1080#MySOCKS5-NoAuth"

        /// Hysteria2 (new support)
        static let hysteria2 = "hy2://password123@hy2.example.com:443?sni=hy2.example.com&insecure=0&obfs=salamander&obfs-password=obfspass123#MyHysteria2"

        /// Hysteria2 minimal
        static let hysteria2Minimal = "hysteria2://password123@hy2.example.com:443#MyHysteria2-Minimal"

        /// Multiple URIs (subscription format)
        static let multipleURIs = """
        # Comment line should be ignored
        vless://550e8400-e29b-41d4-a716-446655440000@server1.example.com:443?security=tls#Server1

        vless://660e8400-e29b-41d4-a716-446655440000@server2.example.com:443?security=tls#Server2
        """

        // Invalid URIs for error testing
        static let invalidBase64 = "vmess://not-valid-base64!!!"
        static let invalidFormat = "vless://no-at-symbol"
        static let unsupportedScheme = "unknown://example.com:443"
    }

    // MARK: - sing-box JSON Configs

    enum SingBox {
        static let vlessOutbound = """
        {
            "outbounds": [
                {
                    "type": "vless",
                    "tag": "vless-out",
                    "server": "example.com",
                    "server_port": 443,
                    "uuid": "550e8400-e29b-41d4-a716-446655440000",
                    "flow": "xtls-rprx-vision",
                    "tls": {
                        "enabled": true,
                        "server_name": "example.com",
                        "insecure": false,
                        "alpn": ["h2", "http/1.1"],
                        "reality": {
                            "enabled": true,
                            "public_key": "abc123publickey",
                            "short_id": "deadbeef"
                        }
                    }
                }
            ]
        }
        """

        static let vmessOutbound = """
        {
            "outbounds": [
                {
                    "type": "vmess",
                    "tag": "vmess-out",
                    "server": "vmess.example.com",
                    "server_port": 443,
                    "uuid": "550e8400-e29b-41d4-a716-446655440000",
                    "alter_id": 0,
                    "security": "auto",
                    "transport": {
                        "type": "ws",
                        "path": "/websocket",
                        "headers": {
                            "Host": "vmess.example.com"
                        }
                    }
                }
            ]
        }
        """

        static let trojanOutbound = """
        {
            "outbounds": [
                {
                    "type": "trojan",
                    "tag": "trojan-out",
                    "server": "trojan.example.com",
                    "server_port": 443,
                    "password": "password123",
                    "tls": {
                        "enabled": true,
                        "server_name": "trojan.example.com",
                        "alpn": ["h2", "http/1.1"]
                    }
                }
            ]
        }
        """

        static let shadowsocksOutbound = """
        {
            "outbounds": [
                {
                    "type": "shadowsocks",
                    "tag": "ss-out",
                    "server": "ss.example.com",
                    "server_port": 8388,
                    "method": "aes-256-gcm",
                    "password": "password123"
                }
            ]
        }
        """

        static let wireguardOutbound = """
        {
            "outbounds": [
                {
                    "type": "wireguard",
                    "tag": "wg-out",
                    "server": "wg.example.com",
                    "server_port": 51820,
                    "private_key": "WG_PRIVATE_KEY_BASE64",
                    "peer_public_key": "WG_PEER_PUBLIC_KEY_BASE64",
                    "reserved": [0, 0, 0]
                }
            ]
        }
        """

        static let hysteria2Outbound = """
        {
            "outbounds": [
                {
                    "type": "hysteria2",
                    "tag": "hy2-out",
                    "server": "hy2.example.com",
                    "server_port": 443,
                    "password": "password123",
                    "obfs": {
                        "type": "salamander",
                        "password": "obfspass123"
                    },
                    "tls": {
                        "enabled": true,
                        "server_name": "hy2.example.com"
                    }
                }
            ]
        }
        """

        static let multipleOutbounds = """
        {
            "outbounds": [
                {
                    "type": "vless",
                    "tag": "vless-1",
                    "server": "server1.example.com",
                    "server_port": 443,
                    "uuid": "uuid-1"
                },
                {
                    "type": "vmess",
                    "tag": "vmess-1",
                    "server": "server2.example.com",
                    "server_port": 443,
                    "uuid": "uuid-2",
                    "alter_id": 0
                },
                {
                    "type": "direct",
                    "tag": "direct"
                },
                {
                    "type": "block",
                    "tag": "block"
                }
            ]
        }
        """

        static let invalidJSON = "{ invalid json }"
        static let missingOutbounds = """
        {
            "log": { "level": "info" }
        }
        """
        static let emptyOutbounds = """
        {
            "outbounds": []
        }
        """
    }

    // MARK: - Clash YAML Configs

    enum Clash {
        static let multiLineProxy = """
        proxies:
          - name: MyVLESS
            type: vless
            server: example.com
            port: 443
            uuid: 550e8400-e29b-41d4-a716-446655440000
            flow: xtls-rprx-vision
            tls: true
            sni: example.com
            skip-cert-verify: false
        """

        static let inlineProxy = """
        proxies:
          - {name: MyVMess, type: vmess, server: vmess.example.com, port: 443, uuid: 550e8400-e29b-41d4-a716-446655440000, alterId: 0, cipher: auto, tls: true}
        """

        static let multipleProxies = """
        proxies:
          - name: Server1
            type: vless
            server: server1.example.com
            port: 443
            uuid: uuid-1
          - name: Server2
            type: trojan
            server: server2.example.com
            port: 443
            password: password123
        proxy-groups:
          - name: Proxy
            type: select
            proxies:
              - Server1
              - Server2
        """

        static let shadowsocksProxy = """
        proxies:
          - name: MySS
            type: ss
            server: ss.example.com
            port: 8388
            cipher: aes-256-gcm
            password: password123
        """

        static let noProxiesSection = """
        dns:
          enable: true
        """
    }

    // MARK: - V2Ray JSON Configs

    enum V2Ray {
        static let vlessVnext = """
        {
            "outbounds": [
                {
                    "protocol": "vless",
                    "tag": "vless-out",
                    "settings": {
                        "vnext": [
                            {
                                "address": "example.com",
                                "port": 443,
                                "users": [
                                    {
                                        "id": "550e8400-e29b-41d4-a716-446655440000",
                                        "flow": "xtls-rprx-vision",
                                        "encryption": "none"
                                    }
                                ]
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "reality",
                        "realitySettings": {
                            "publicKey": "abc123publickey",
                            "shortId": "deadbeef",
                            "serverName": "www.microsoft.com"
                        }
                    }
                }
            ]
        }
        """

        static let vmessVnext = """
        {
            "outbounds": [
                {
                    "protocol": "vmess",
                    "tag": "vmess-out",
                    "settings": {
                        "vnext": [
                            {
                                "address": "vmess.example.com",
                                "port": 443,
                                "users": [
                                    {
                                        "id": "550e8400-e29b-41d4-a716-446655440000",
                                        "alterId": 0,
                                        "security": "auto"
                                    }
                                ]
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": "ws",
                        "security": "tls",
                        "tlsSettings": {
                            "serverName": "vmess.example.com",
                            "alpn": ["h2", "http/1.1"]
                        },
                        "wsSettings": {
                            "path": "/websocket",
                            "headers": {
                                "Host": "vmess.example.com"
                            }
                        }
                    }
                }
            ]
        }
        """

        static let trojanServers = """
        {
            "outbounds": [
                {
                    "protocol": "trojan",
                    "tag": "trojan-out",
                    "settings": {
                        "servers": [
                            {
                                "address": "trojan.example.com",
                                "port": 443,
                                "password": "password123"
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "serverName": "trojan.example.com"
                        }
                    }
                }
            ]
        }
        """
    }

    // MARK: - Test Services (Basic)

    static func makeVLESSService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test VLESS",
            protocol: .vless,
            server: "example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "flow": .string("xtls-rprx-vision"),
                "sni": .string("example.com"),
                "tls": .bool(true),
                "reality": .bool(true),
                "realityPublicKey": .string("abc123publickey"),
                "realityShortId": .string("deadbeef"),
                "fingerprint": .string("chrome")
            ]
        )
    }

    static func makeVMessService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test VMess",
            protocol: .vmess,
            server: "vmess.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "alterId": .int(0),
                "security": .string("auto"),
                "network": .string("ws"),
                "wsPath": .string("/websocket"),
                "wsHost": .string("vmess.example.com"),
                "sni": .string("vmess.example.com"),
                "tls": .bool(true)
            ]
        )
    }

    static func makeTrojanService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test Trojan",
            protocol: .trojan,
            server: "trojan.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("trojan.example.com"),
                "tls": .bool(true),
                "alpn": .string("h2,http/1.1")
            ]
        )
    }

    static func makeShadowsocksService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test Shadowsocks",
            protocol: .shadowsocks,
            server: "ss.example.com",
            port: 8388,
            credentialRef: credentialRef,
            settings: [
                "method": .string("aes-256-gcm")
            ]
        )
    }

    static func makeWireGuardService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test WireGuard",
            protocol: .wireguard,
            server: "wg.example.com",
            port: 51820,
            credentialRef: credentialRef,
            settings: [
                "publicKey": .string("PEER_PUBLIC_KEY"),
                "reserved": .string("0,0,0"),
                "localAddressIPv4": .string("10.0.0.2/32")
            ]
        )
    }

    static func makeHysteria2Service(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Test Hysteria2",
            protocol: .hysteria2,
            server: "hy2.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("hy2.example.com"),
                "tls": .bool(true),
                "obfs": .string("obfspass123"),
                "up": .string("100"),
                "down": .string("100")
            ]
        )
    }

    // MARK: - Full-Featured Protocol Services (sing-box 1.12+ compliant)

    /// VLESS with Reality + XTLS Vision + uTLS (maximum options)
    static func makeVLESSRealityFullService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "VLESS Reality Full",
            protocol: .vless,
            server: "vless.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "flow": .string("xtls-rprx-vision"),
                "sni": .string("www.microsoft.com"),
                "tls": .bool(true),
                "reality": .bool(true),
                "realityPublicKey": .string("jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0"),
                "realityShortId": .string("0123456789abcdef"),
                "fingerprint": .string("chrome"),
                "alpn": .string("h2,http/1.1")
            ]
        )
    }

    /// VLESS with gRPC transport
    static func makeVLESSgRPCService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "VLESS gRPC",
            protocol: .vless,
            server: "vless-grpc.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "flow": .string(""),
                "sni": .string("vless-grpc.example.com"),
                "tls": .bool(true),
                "network": .string("grpc"),
                "grpcServiceName": .string("TunService"),
                "fingerprint": .string("firefox")
            ]
        )
    }

    /// VLESS with WebSocket transport
    static func makeVLESSWebSocketService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "VLESS WebSocket",
            protocol: .vless,
            server: "vless-ws.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("vless-ws.example.com"),
                "tls": .bool(true),
                "network": .string("ws"),
                "wsPath": .string("/vless-ws"),
                "wsHost": .string("vless-ws.example.com"),
                "fingerprint": .string("safari")
            ]
        )
    }

    /// VLESS with HTTP/2 transport
    static func makeVLESSHTTPService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "VLESS HTTP/2",
            protocol: .vless,
            server: "vless-h2.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("vless-h2.example.com"),
                "tls": .bool(true),
                "network": .string("h2"),
                "httpPath": .string("/vless-http"),
                "httpHost": .string("vless-h2.example.com")
            ]
        )
    }

    /// VMess with all security options
    static func makeVMessSecurityService(
        credentialRef: String = "test-cred-ref",
        security: String = "chacha20-poly1305"
    ) -> Service {
        Service(
            name: "VMess \(security)",
            protocol: .vmess,
            server: "vmess.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "alterId": .int(0),
                "security": .string(security),
                "sni": .string("vmess.example.com"),
                "tls": .bool(true),
                "fingerprint": .string("chrome")
            ]
        )
    }

    /// VMess with gRPC transport
    static func makeVMessgRPCService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "VMess gRPC",
            protocol: .vmess,
            server: "vmess-grpc.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "alterId": .int(0),
                "security": .string("auto"),
                "sni": .string("vmess-grpc.example.com"),
                "tls": .bool(true),
                "network": .string("grpc"),
                "grpcServiceName": .string("VMGrpcService")
            ]
        )
    }

    /// Trojan with gRPC transport
    static func makeTrojangRPCService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Trojan gRPC",
            protocol: .trojan,
            server: "trojan-grpc.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("trojan-grpc.example.com"),
                "tls": .bool(true),
                "network": .string("grpc"),
                "grpcServiceName": .string("TrojanService"),
                "alpn": .string("h2")
            ]
        )
    }

    /// Trojan with WebSocket transport
    static func makeTrojanWebSocketService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Trojan WebSocket",
            protocol: .trojan,
            server: "trojan-ws.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("trojan-ws.example.com"),
                "tls": .bool(true),
                "network": .string("ws"),
                "wsPath": .string("/trojan-ws"),
                "wsHost": .string("trojan-ws.example.com")
            ]
        )
    }

    /// Shadowsocks with AEAD 2022 cipher
    static func makeShadowsocks2022Service(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Shadowsocks 2022",
            protocol: .shadowsocks,
            server: "ss.example.com",
            port: 8388,
            credentialRef: credentialRef,
            settings: [
                "method": .string("2022-blake3-aes-256-gcm")
            ]
        )
    }

    /// Shadowsocks with ChaCha20 cipher
    static func makeShadowsocksChaChaService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Shadowsocks ChaCha",
            protocol: .shadowsocks,
            server: "ss.example.com",
            port: 8388,
            credentialRef: credentialRef,
            settings: [
                "method": .string("chacha20-ietf-poly1305")
            ]
        )
    }

    /// WireGuard with full peer config + IPv6
    static func makeWireGuardFullService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "WireGuard Full",
            protocol: .wireguard,
            server: "wg.example.com",
            port: 51820,
            credentialRef: credentialRef,
            settings: [
                "publicKey": .string("Z1XXLsKYkYxuiYjJIkRvtIKFepCYHTgON+GwPq7SOV4="),
                "preSharedKey": .string("31aIhAPwktDGpH4JDhA8GNvjFXEf/a6+UaQRyOAiyfM="),
                "reserved": .string("1,2,3"),
                "localAddressIPv4": .string("10.0.0.2/32"),
                "localAddressIPv6": .string("fd00::2/128"),
                "mtu": .int(1408)
            ]
        )
    }

    /// Hysteria2 with port hopping (full options)
    static func makeHysteria2FullService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Hysteria2 Full",
            protocol: .hysteria2,
            server: "hy2.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("hy2.example.com"),
                "tls": .bool(true),
                "obfs": .string("salamander-obfs-password"),
                "up": .string("100"),
                "down": .string("100"),
                "alpn": .string("h3")
            ]
        )
    }

    /// Hysteria2 minimal (no obfs)
    static func makeHysteria2MinimalService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Hysteria2 Minimal",
            protocol: .hysteria2,
            server: "hy2-min.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("hy2-min.example.com"),
                "tls": .bool(true)
            ]
        )
    }

    /// SOCKS5 service with authentication
    static func makeSOCKS5Service(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "SOCKS5 Auth",
            protocol: .socks5,
            server: "socks.example.com",
            port: 1080,
            credentialRef: credentialRef,
            settings: [
                "username": .string("socksuser")
            ]
        )
    }

    /// SOCKS5 service without authentication
    static func makeSOCKS5NoAuthService() -> Service {
        Service(
            name: "SOCKS5 NoAuth",
            protocol: .socks5,
            server: "socks-noauth.example.com",
            port: 1080,
            settings: [:]
        )
    }

    // MARK: - TLS Configuration Variants

    /// Service with insecure TLS (skip-cert-verify)
    static func makeInsecureTLSService(credentialRef: String = "test-cred-ref") -> Service {
        Service(
            name: "Insecure TLS",
            protocol: .trojan,
            server: "insecure.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("insecure.example.com"),
                "tls": .bool(true),
                "allowInsecure": .bool(true)
            ]
        )
    }

    /// Service with uTLS fingerprint variants
    static func makeUTLSService(
        credentialRef: String = "test-cred-ref",
        fingerprint: String = "chrome"
    ) -> Service {
        Service(
            name: "uTLS \(fingerprint)",
            protocol: .vless,
            server: "utls.example.com",
            port: 443,
            credentialRef: credentialRef,
            settings: [
                "sni": .string("utls.example.com"),
                "tls": .bool(true),
                "fingerprint": .string(fingerprint)
            ]
        )
    }

    // MARK: - Tunnel Config

    static func makeDefaultTunnelConfig() -> TunnelConfig {
        TunnelConfig(
            mode: .full,
            chain: [],
            rules: []
        )
    }

    static func makeSplitTunnelConfig() -> TunnelConfig {
        TunnelConfig(
            mode: .split,
            chain: [],
            rules: [
                RoutingRule(type: .domain, value: "example.com", outbound: .proxy),
                RoutingRule(type: .geoip, value: "CN", outbound: .direct),
                RoutingRule(type: .geosite, value: "category-ads", outbound: .block)
            ]
        )
    }

    /// Config with all rule types for comprehensive testing
    static func makeFullRulesTunnelConfig() -> TunnelConfig {
        TunnelConfig(
            mode: .split,
            chain: [],
            rules: [
                // Domain rules
                RoutingRule(type: .domain, value: "exact.example.com", outbound: .proxy),
                RoutingRule(type: .domainSuffix, value: ".google.com", outbound: .direct),
                RoutingRule(type: .domainKeyword, value: "facebook", outbound: .proxy),

                // IP rules
                RoutingRule(type: .ipCidr, value: "10.0.0.0/8", outbound: .direct),
                RoutingRule(type: .ipCidr, value: "192.168.0.0/16", outbound: .direct),

                // Geo rules
                RoutingRule(type: .geoip, value: "CN", outbound: .direct),
                RoutingRule(type: .geoip, value: "private", outbound: .direct),
                RoutingRule(type: .geosite, value: "category-ads", outbound: .block),
                RoutingRule(type: .geosite, value: "cn", outbound: .direct),

                // Process rules
                RoutingRule(type: .processName, value: "Safari", outbound: .direct),
                RoutingRule(type: .processName, value: "curl", outbound: .proxy),
                RoutingRule(type: .processPath, value: "/usr/bin/ssh", outbound: .direct)
            ]
        )
    }
}

// swiftlint:enable line_length
