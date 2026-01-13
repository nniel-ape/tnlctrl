//
//  ConfigExporter.swift
//  TunnelMaster
//
//  Export services to various config formats for backup/sharing.
//

import Foundation

struct ConfigExporter {

    // MARK: - sing-box Export

    func exportToSingBox(services: [Service], includeCredentials: Bool = false) -> String {
        var outbounds: [[String: Any]] = []

        for service in services {
            var outbound = buildBaseOutbound(service)

            if !includeCredentials {
                // Remove credentials, leave placeholders
                outbound.removeValue(forKey: "uuid")
                outbound.removeValue(forKey: "password")
                outbound.removeValue(forKey: "private_key")
            }

            outbounds.append(outbound)
        }

        // Add direct and block outbounds
        outbounds.append(["tag": "direct", "type": "direct"])
        outbounds.append(["tag": "block", "type": "block"])

        let config: [String: Any] = [
            "outbounds": outbounds
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    // MARK: - Clash Export

    func exportToClash(services: [Service], includeCredentials: Bool = false) -> String {
        var lines: [String] = []

        lines.append("# TunnelMaster Export")
        lines.append("# Generated: \(Date().formatted())")
        lines.append("")
        lines.append("proxies:")

        for service in services {
            let proxy = buildClashProxy(service, includeCredentials: includeCredentials)
            lines.append(proxy)
        }

        lines.append("")
        lines.append("proxy-groups:")
        lines.append("  - name: \"auto\"")
        lines.append("    type: url-test")
        lines.append("    proxies:")
        for service in services {
            lines.append("      - \"\(service.name)\"")
        }
        lines.append("    url: \"http://www.gstatic.com/generate_204\"")
        lines.append("    interval: 300")

        return lines.joined(separator: "\n")
    }

    // MARK: - URI Export

    func exportToURIs(services: [Service], includeCredentials: Bool = false) -> [String] {
        services.compactMap { service in
            buildURI(service, includeCredentials: includeCredentials)
        }
    }

    // MARK: - Helpers

    private func buildBaseOutbound(_ service: Service) -> [String: Any] {
        var outbound: [String: Any] = [
            "tag": service.name.lowercased().replacingOccurrences(of: " ", with: "-"),
            "type": singBoxType(for: service.protocol),
            "server": service.server,
            "server_port": service.port
        ]

        // Add protocol-specific settings
        for (key, value) in service.settings {
            outbound[key] = anyValue(from: value)
        }

        return outbound
    }

    private func buildClashProxy(_ service: Service, includeCredentials: Bool) -> String {
        var lines: [String] = []
        let indent = "    "

        lines.append("  - name: \"\(service.name)\"")
        lines.append("\(indent)type: \(clashType(for: service.protocol))")
        lines.append("\(indent)server: \(service.server)")
        lines.append("\(indent)port: \(service.port)")

        switch service.protocol {
        case .vless:
            if includeCredentials, let uuid = service.settings["uuid"]?.stringValue {
                lines.append("\(indent)uuid: \(uuid)")
            } else {
                lines.append("\(indent)uuid: \"YOUR_UUID_HERE\"")
            }
            if let flow = service.settings["flow"]?.stringValue {
                lines.append("\(indent)flow: \(flow)")
            }

        case .vmess:
            if includeCredentials, let uuid = service.settings["uuid"]?.stringValue {
                lines.append("\(indent)uuid: \(uuid)")
            } else {
                lines.append("\(indent)uuid: \"YOUR_UUID_HERE\"")
            }
            lines.append("\(indent)alterId: \(service.settings["alterId"]?.intValue ?? 0)")
            lines.append("\(indent)cipher: \(service.settings["security"]?.stringValue ?? "auto")")

        case .trojan:
            if includeCredentials, let password = service.settings["password"]?.stringValue {
                lines.append("\(indent)password: \(password)")
            } else {
                lines.append("\(indent)password: \"YOUR_PASSWORD_HERE\"")
            }

        case .shadowsocks:
            lines.append("\(indent)cipher: \(service.settings["method"]?.stringValue ?? "aes-256-gcm")")
            if includeCredentials, let password = service.settings["password"]?.stringValue {
                lines.append("\(indent)password: \(password)")
            } else {
                lines.append("\(indent)password: \"YOUR_PASSWORD_HERE\"")
            }

        case .socks5:
            if let username = service.settings["username"]?.stringValue {
                lines.append("\(indent)username: \(username)")
                if includeCredentials, let password = service.settings["password"]?.stringValue {
                    lines.append("\(indent)password: \(password)")
                } else {
                    lines.append("\(indent)password: \"YOUR_PASSWORD_HERE\"")
                }
            }

        case .wireguard, .hysteria2:
            lines.append("\(indent)# \(service.protocol.displayName) export not fully supported in Clash")
        }

        // TLS settings
        if service.settings["tls"]?.boolValue == true {
            lines.append("\(indent)tls: true")
            if let sni = service.settings["sni"]?.stringValue {
                lines.append("\(indent)sni: \(sni)")
            }
            if service.settings["allowInsecure"]?.boolValue == true {
                lines.append("\(indent)skip-cert-verify: true")
            }
        }

        // Network/Transport
        if let network = service.settings["network"]?.stringValue, network == "ws" {
            lines.append("\(indent)network: ws")
            if let path = service.settings["wsPath"]?.stringValue {
                lines.append("\(indent)ws-opts:")
                lines.append("\(indent)  path: \(path)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func buildURI(_ service: Service, includeCredentials: Bool) -> String? {
        switch service.protocol {
        case .vless:
            return buildVLESSURI(service, includeCredentials: includeCredentials)
        case .vmess:
            return buildVMessURI(service, includeCredentials: includeCredentials)
        case .trojan:
            return buildTrojanURI(service, includeCredentials: includeCredentials)
        case .shadowsocks:
            return buildShadowsocksURI(service, includeCredentials: includeCredentials)
        case .socks5:
            return buildSOCKS5URI(service, includeCredentials: includeCredentials)
        default:
            return nil
        }
    }

    private func buildVLESSURI(_ service: Service, includeCredentials: Bool) -> String {
        let uuid = includeCredentials ? (service.settings["uuid"]?.stringValue ?? "UUID") : "UUID"
        var uri = "vless://\(uuid)@\(service.server):\(service.port)"

        var params: [String] = []
        if let flow = service.settings["flow"]?.stringValue {
            params.append("flow=\(flow)")
        }
        if service.settings["tls"]?.boolValue == true {
            params.append("security=tls")
            if let sni = service.settings["sni"]?.stringValue {
                params.append("sni=\(sni)")
            }
        }

        if !params.isEmpty {
            uri += "?" + params.joined(separator: "&")
        }

        uri += "#\(service.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? service.name)"
        return uri
    }

    private func buildVMessURI(_ service: Service, includeCredentials: Bool) -> String {
        let config: [String: Any] = [
            "v": "2",
            "ps": service.name,
            "add": service.server,
            "port": service.port,
            "id": includeCredentials ? (service.settings["uuid"]?.stringValue ?? "UUID") : "UUID",
            "aid": service.settings["alterId"]?.intValue ?? 0,
            "scy": service.settings["security"]?.stringValue ?? "auto",
            "net": service.settings["network"]?.stringValue ?? "tcp",
            "type": "none",
            "host": service.settings["wsHost"]?.stringValue ?? "",
            "path": service.settings["wsPath"]?.stringValue ?? "",
            "tls": service.settings["tls"]?.boolValue == true ? "tls" : ""
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config),
           let json = String(data: data, encoding: .utf8) {
            let encoded = Data(json.utf8).base64EncodedString()
            return "vmess://\(encoded)"
        }
        return ""
    }

    private func buildTrojanURI(_ service: Service, includeCredentials: Bool) -> String {
        let password = includeCredentials ? (service.settings["password"]?.stringValue ?? "PASSWORD") : "PASSWORD"
        var uri = "trojan://\(password)@\(service.server):\(service.port)"

        var params: [String] = []
        if let sni = service.settings["sni"]?.stringValue {
            params.append("sni=\(sni)")
        }

        if !params.isEmpty {
            uri += "?" + params.joined(separator: "&")
        }

        uri += "#\(service.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? service.name)"
        return uri
    }

    private func buildShadowsocksURI(_ service: Service, includeCredentials: Bool) -> String {
        let method = service.settings["method"]?.stringValue ?? "aes-256-gcm"
        let password = includeCredentials ? (service.settings["password"]?.stringValue ?? "PASSWORD") : "PASSWORD"

        let userInfo = "\(method):\(password)"
        let encoded = Data(userInfo.utf8).base64EncodedString()

        var uri = "ss://\(encoded)@\(service.server):\(service.port)"
        uri += "#\(service.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? service.name)"
        return uri
    }

    private func buildSOCKS5URI(_ service: Service, includeCredentials: Bool) -> String {
        var uri = "socks5://"

        if let username = service.settings["username"]?.stringValue {
            let password = includeCredentials ? (service.settings["password"]?.stringValue ?? "PASSWORD") : "PASSWORD"
            uri += "\(username):\(password)@"
        }

        uri += "\(service.server):\(service.port)"
        uri += "#\(service.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? service.name)"
        return uri
    }

    private func singBoxType(for protocol: ProxyProtocol) -> String {
        switch `protocol` {
        case .vless: "vless"
        case .vmess: "vmess"
        case .trojan: "trojan"
        case .shadowsocks: "shadowsocks"
        case .socks5: "socks"
        case .wireguard: "wireguard"
        case .hysteria2: "hysteria2"
        }
    }

    private func clashType(for protocol: ProxyProtocol) -> String {
        switch `protocol` {
        case .vless: "vless"
        case .vmess: "vmess"
        case .trojan: "trojan"
        case .shadowsocks: "ss"
        case .socks5: "socks5"
        case .wireguard: "wireguard"
        case .hysteria2: "hysteria2"
        }
    }

    private func anyValue(from value: AnyCodableValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let a): return a.map { anyValue(from: $0) }
        case .dictionary(let d): return d.mapValues { anyValue(from: $0) }
        case .null: return NSNull()
        }
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case singbox = "sing-box"
    case clash = "Clash"
    case uris = "URIs"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .singbox: "json"
        case .clash: "yaml"
        case .uris: "txt"
        }
    }
}
