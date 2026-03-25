//
//  ProxyProtocol.swift
//  tnl_ctrl
//

import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case vless
    case vmess
    case trojan
    case shadowsocks
    case socks5
    case wireguard
    case hysteria2

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .vless: "VLESS"
        case .vmess: "VMess"
        case .trojan: "Trojan"
        case .shadowsocks: "Shadowsocks"
        case .socks5: "SOCKS5"
        case .wireguard: "WireGuard"
        case .hysteria2: "Hysteria2"
        }
    }

    var defaultPort: Int {
        switch self {
        case .vless, .vmess, .trojan: 443
        case .shadowsocks: 8388
        case .socks5: 1080
        case .wireguard: 51820
        case .hysteria2: 443
        }
    }

    var systemImage: String {
        switch self {
        case .vless, .vmess: "bolt.shield"
        case .trojan: "shield.lefthalf.filled"
        case .shadowsocks: "moon.fill"
        case .socks5: "network"
        case .wireguard: "lock.shield"
        case .hysteria2: "bolt.horizontal"
        }
    }

    var tagline: String {
        switch self {
        case .vless: "Modern, lightweight"
        case .vmess: "V2Ray protocol"
        case .trojan: "TLS-based stealth"
        case .shadowsocks: "Classic encrypted"
        case .socks5: "Simple proxy"
        case .wireguard: "Fast VPN tunnel"
        case .hysteria2: "QUIC-based, fast"
        }
    }

    var defaultSettings: [String: AnyCodableValue] {
        switch self {
        case .vless:
            ["tls": .bool(true), "fingerprint": .string("chrome"), "flow": .string("")]
        case .vmess:
            ["tls": .bool(true), "fingerprint": .string("chrome"), "security": .string("auto"), "alterId": .int(0)]
        case .trojan:
            ["tls": .bool(true), "fingerprint": .string("chrome")]
        case .shadowsocks:
            ["method": .string("aes-256-gcm")]
        case .wireguard:
            ["mtu": .int(1420)]
        case .hysteria2:
            ["tls": .bool(true)]
        case .socks5:
            [:]
        }
    }
}
