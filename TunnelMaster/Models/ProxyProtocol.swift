//
//  ProxyProtocol.swift
//  TunnelMaster
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

    var id: String { rawValue }

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
}
