//
//  LinkParser.swift
//  tnl_ctrl
//
//  Parses proxy share-link URIs into Service models.
//

import Foundation

enum LinkParser {
    struct ParseResult {
        let service: Service
        let credential: String?
    }

    // MARK: - Public API

    static func parse(_ string: String) -> ParseResult? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // VMess uses a non-standard URI format (base64 JSON)
        if trimmed.lowercased().hasPrefix("vmess://") {
            return parseVMess(trimmed)
        }

        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty
        else {
            return nil
        }

        switch scheme {
        case "vless":
            return parseVLESS(components, trimmed: trimmed)
        case "trojan":
            return parseTrojan(components, trimmed: trimmed)
        case "ss":
            return parseShadowsocks(components, trimmed: trimmed)
        case "socks5", "socks":
            return parseSOCKS5(components, trimmed: trimmed)
        case "hysteria2", "hy2":
            return parseHysteria2(components, trimmed: trimmed)
        default:
            return nil
        }
    }

    static func parseBatch(_ string: String) -> (results: [ParseResult], errors: [String]) {
        let lines = string.components(separatedBy: .newlines)
        var results: [ParseResult] = []
        var errors: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let result = parse(trimmed) {
                results.append(result)
            } else {
                let preview = trimmed.count > 40 ? String(trimmed.prefix(40)) + "..." : trimmed
                errors.append("Line \(index + 1): \(preview)")
            }
        }

        return (results, errors)
    }

    // MARK: - VLESS

    private static func parseVLESS(_ components: URLComponents, trimmed: String) -> ParseResult? {
        guard let uuid = components.user?.trimmingCharacters(in: .whitespaces), !uuid.isEmpty else {
            return nil
        }

        let port = components.port ?? ProxyProtocol.vless.defaultPort
        let name = decodeFragment(components.fragment) ?? "VLESS Service"

        var settings = ProxyProtocol.vless.defaultSettings
        let params = queryParams(from: components)

        // TLS / security
        if let security = params["security"]?.lowercased() {
            if security == "none" {
                settings["tls"] = .bool(false)
            } else if security == "tls" || security == "reality" || security == "xtls" {
                settings["tls"] = .bool(true)
            }
        }

        // SNI
        if let sni = params["sni"] {
            settings["sni"] = .string(sni)
        }

        // Fingerprint
        if let fp = params["fp"] ?? params["fingerprint"] {
            settings["fingerprint"] = .string(fp)
        }

        // Flow
        if let flow = params["flow"], !flow.isEmpty {
            settings["flow"] = .string(flow)
        }

        // Transport
        if let network = params["type"] ?? params["net"] {
            settings["network"] = .string(network)
            applyTransportSettings(&settings, network: network, params: params)
        }

        // Reality
        if let pbk = params["pbk"] {
            settings["reality"] = .bool(true)
            settings["realityPublicKey"] = .string(pbk)
        }
        if let sid = params["sid"] {
            settings["realityShortId"] = .string(sid)
        }

        // ALPN
        if let alpn = params["alpn"] {
            settings["alpn"] = .string(alpn)
        }

        // Allow insecure
        if params["allowinsecure"] == "1" || params["insecure"] == "1" {
            settings["allowInsecure"] = .bool(true)
        }

        let service = Service(
            name: name,
            protocol: .vless,
            server: components.host!,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: uuid)
    }

    // MARK: - VMess

    private static func parseVMess(_ string: String) -> ParseResult? {
        let base64Part = String(string.dropFirst("vmess://".count))
        guard let data = base64Decode(base64Part),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        guard let uuid = json["id"] as? String, !uuid.isEmpty,
              let server = json["add"] as? String, !server.isEmpty
        else {
            return nil
        }

        let port = parsePort(from: json["port"]) ?? ProxyProtocol.vmess.defaultPort
        let name = (json["ps"] as? String)?.trimmingCharacters(in: .whitespaces) ?? "VMess Service"

        var settings = ProxyProtocol.vmess.defaultSettings

        // Security / alterId
        if let scy = json["scy"] as? String, !scy.isEmpty {
            settings["security"] = .string(scy)
        }
        if let aid = json["aid"] {
            settings["alterId"] = .int(parseInt(from: aid) ?? 0)
        }

        // TLS
        if let tls = json["tls"] as? String, !tls.isEmpty {
            if tls == "tls" || tls == "reality" {
                settings["tls"] = .bool(true)
            }
        }

        // SNI
        if let sni = json["sni"] as? String, !sni.isEmpty {
            settings["sni"] = .string(sni)
        }

        // Fingerprint
        if let fp = json["fp"] as? String, !fp.isEmpty {
            settings["fingerprint"] = .string(fp)
        }

        // Transport
        if let network = json["net"] as? String, !network.isEmpty {
            settings["network"] = .string(network)

            let host = json["host"] as? String
            let path = json["path"] as? String
            let params = host != nil || path != nil
                ? ["host": host, "path": path].compactMapValues { $0 }
                : [:]
            applyTransportSettings(&settings, network: network, params: params)
        }

        // Reality
        if let pbk = json["pbk"] as? String, !pbk.isEmpty {
            settings["reality"] = .bool(true)
            settings["realityPublicKey"] = .string(pbk)
        }
        if let sid = json["sid"] as? String, !sid.isEmpty {
            settings["realityShortId"] = .string(sid)
        }

        let service = Service(
            name: name,
            protocol: .vmess,
            server: server,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: uuid)
    }

    // MARK: - Trojan

    private static func parseTrojan(_ components: URLComponents, trimmed: String) -> ParseResult? {
        guard let password = components.user?.trimmingCharacters(in: .whitespaces), !password.isEmpty else {
            return nil
        }

        let port = components.port ?? ProxyProtocol.trojan.defaultPort
        let name = decodeFragment(components.fragment) ?? "Trojan Service"

        var settings = ProxyProtocol.trojan.defaultSettings
        let params = queryParams(from: components)

        // TLS / security
        if let security = params["security"]?.lowercased() {
            if security == "none" {
                settings["tls"] = .bool(false)
            } else if security == "tls" || security == "reality" {
                settings["tls"] = .bool(true)
            }
        }

        if let sni = params["sni"] {
            settings["sni"] = .string(sni)
        }
        if let fp = params["fp"] ?? params["fingerprint"] {
            settings["fingerprint"] = .string(fp)
        }
        if let network = params["type"] ?? params["net"] {
            settings["network"] = .string(network)
            applyTransportSettings(&settings, network: network, params: params)
        }
        if let alpn = params["alpn"] {
            settings["alpn"] = .string(alpn)
        }
        if params["allowinsecure"] == "1" || params["insecure"] == "1" {
            settings["allowInsecure"] = .bool(true)
        }

        let service = Service(
            name: name,
            protocol: .trojan,
            server: components.host!,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: password)
    }

    // MARK: - Shadowsocks

    private static func parseShadowsocks(_ components: URLComponents, trimmed: String) -> ParseResult? {
        let port = components.port ?? ProxyProtocol.shadowsocks.defaultPort
        let name = decodeFragment(components.fragment) ?? "Shadowsocks Service"

        var method: String?
        var password: String?

        // Reconstruct full userInfo from user + password (URLComponents splits on ':')
        let rawUserInfo: String? = {
            guard let user = components.user else { return nil }
            if let pwd = components.password, !pwd.isEmpty {
                return "\(user):\(pwd)"
            }
            return user
        }()

        if let userInfo = rawUserInfo {
            // Try base64-decoding the userInfo (SIP002: base64(method:password))
            if let decodedData = base64Decode(userInfo),
               let decoded = String(data: decodedData, encoding: .utf8) {
                let parts = decoded.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    method = String(parts[0])
                    password = String(parts[1])
                }
            }

            // If base64 decode failed, try plain method:password
            if method == nil {
                let parts = userInfo.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    method = String(parts[0])
                    password = String(parts[1])
                }
            }
        }

        guard let method, !method.isEmpty else {
            return nil
        }

        var settings = ProxyProtocol.shadowsocks.defaultSettings
        settings["method"] = .string(method)

        let params = queryParams(from: components)
        if let plugin = params["plugin"], !plugin.isEmpty {
            // plugin format: "plugin-name;opt1=value1;opt2=value2"
            let pluginParts = plugin.split(separator: ";")
            if let pluginName = pluginParts.first {
                settings["plugin"] = .string(String(pluginName))
            }
            if pluginParts.count > 1 {
                let opts = pluginParts.dropFirst().joined(separator: ";")
                settings["pluginOpts"] = .string(opts)
            }
        }

        let service = Service(
            name: name,
            protocol: .shadowsocks,
            server: components.host!,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: password)
    }

    // MARK: - SOCKS5

    private static func parseSOCKS5(_ components: URLComponents, trimmed: String) -> ParseResult? {
        let port = components.port ?? ProxyProtocol.socks5.defaultPort
        let name = decodeFragment(components.fragment) ?? "SOCKS5 Service"

        var settings: [String: AnyCodableValue] = [:]
        var credential: String?

        if let username = components.user, !username.isEmpty {
            settings["username"] = .string(username)
            if let pwd = components.password, !pwd.isEmpty {
                credential = pwd
            }
        }

        let service = Service(
            name: name,
            protocol: .socks5,
            server: components.host!,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: credential)
    }

    // MARK: - Hysteria2

    private static func parseHysteria2(_ components: URLComponents, trimmed: String) -> ParseResult? {
        let password = components.user?.trimmingCharacters(in: .whitespaces)
        let port = components.port ?? ProxyProtocol.hysteria2.defaultPort
        let name = decodeFragment(components.fragment) ?? "Hysteria2 Service"

        var settings = ProxyProtocol.hysteria2.defaultSettings
        settings["tls"] = .bool(true)

        let params = queryParams(from: components)

        // SNI (required for Hysteria2)
        if let sni = params["sni"] {
            settings["sni"] = .string(sni)
        }

        // Bandwidth
        if let up = params["up"] ?? params["upmbps"] {
            settings["up"] = .string(up)
        }
        if let down = params["down"] ?? params["downmbps"] {
            settings["down"] = .string(down)
        }

        // Obfs
        if let obfs = params["obfs"] ?? params["obfs-password"] {
            settings["obfs"] = .string(obfs)
        }

        // Port hopping
        if let mport = params["mport"] ?? params["server_ports"] {
            settings["serverPorts"] = .string(mport)
        }
        if let hopInterval = params["hop_interval"] {
            settings["hopInterval"] = .string(hopInterval)
        }

        // Insecure
        if params["insecure"] == "1" || params["allowinsecure"] == "1" {
            settings["allowInsecure"] = .bool(true)
        }

        let service = Service(
            name: name,
            protocol: .hysteria2,
            server: components.host!,
            port: port,
            settings: settings
        )

        return ParseResult(service: service, credential: password)
    }

    // MARK: - Transport Helpers

    private static func applyTransportSettings(
        _ settings: inout [String: AnyCodableValue],
        network: String,
        params: [String: String]
    ) {
        switch network.lowercased() {
        case "ws":
            if let path = params["path"] {
                settings["wsPath"] = .string(path)
            }
            if let host = params["host"] {
                settings["wsHost"] = .string(host)
            }
            if let earlyData = params["earlydata"], let size = Int(earlyData) {
                settings["wsEarlyData"] = .string(earlyData)
            }
        case "grpc":
            if let serviceName = params["servicename"] {
                settings["grpcServiceName"] = .string(serviceName)
            }
        case "http", "h2":
            if let path = params["path"] {
                settings["httpPath"] = .string(path)
            }
            if let host = params["host"] {
                settings["httpHost"] = .string(host)
            }
        case "httpupgrade":
            if let path = params["path"] {
                settings["httpUpgradePath"] = .string(path)
            }
            if let host = params["host"] {
                settings["httpUpgradeHost"] = .string(host)
            }
        case "quic":
            break // No additional settings
        default:
            break
        }
    }

    // MARK: - Utility

    private static func queryParams(from components: URLComponents) -> [String: String] {
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                params[item.name.lowercased()] = value
            }
        }
        return params
    }

    private static func decodeFragment(_ fragment: String?) -> String? {
        guard let fragment else { return nil }
        return fragment.removingPercentEncoding?.trimmingCharacters(in: .whitespaces)
    }

    private static func base64Decode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding
        let padding = 4 - (base64.count % 4)
        if padding != 4 {
            base64.append(String(repeating: "=", count: padding))
        }

        return Data(base64Encoded: base64)
    }

    private static func parsePort(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func parseInt(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        return nil
    }
}
