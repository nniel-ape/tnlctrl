//
//  URIParser.swift
//  TunnelMaster
//

import Foundation

struct URIParser: ConfigImporter {
    func canImport(data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else { return false }
        return canImport(text: text)
    }

    func canImport(text: String) -> Bool {
        let schemes = ["ss://", "vmess://", "vless://", "trojan://", "socks://", "socks5://"]
        return schemes.contains { text.lowercased().hasPrefix($0) }
    }

    func parse(data: Data) async throws -> [Service] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ConfigImportError.invalidEncoding
        }
        return try await parse(text: text)
    }

    func parse(text: String) async throws -> [Service] {
        // Handle multiple URIs (one per line, or subscription format)
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        var services: [Service] = []

        for line in lines {
            if let service = try await parseURI(line) {
                services.append(service)
            }
        }

        return services
    }

    // MARK: - URI Parsing

    private func parseURI(_ uri: String) async throws -> Service? {
        let lowercased = uri.lowercased()

        if lowercased.hasPrefix("ss://") {
            return try await parseShadowsocks(uri)
        } else if lowercased.hasPrefix("vmess://") {
            return try await parseVMess(uri)
        } else if lowercased.hasPrefix("vless://") {
            return try await parseVLESS(uri)
        } else if lowercased.hasPrefix("trojan://") {
            return try await parseTrojan(uri)
        } else if lowercased.hasPrefix("socks://") || lowercased.hasPrefix("socks5://") {
            return try await parseSOCKS5(uri)
        }

        return nil
    }

    // MARK: - Shadowsocks

    private func parseShadowsocks(_ uri: String) async throws -> Service? {
        // Format 1: ss://BASE64(method:password)@host:port#name
        // Format 2 (SIP002): ss://BASE64(method:password)@host:port?plugin=...#name

        var workingURI = String(uri.dropFirst(5)) // Remove "ss://"

        // Extract fragment (name)
        var name = "Shadowsocks"
        if let hashIndex = workingURI.lastIndex(of: "#") {
            name = String(workingURI[workingURI.index(after: hashIndex)...])
                .removingPercentEncoding ?? name
            workingURI = String(workingURI[..<hashIndex])
        }

        // Extract query params (used for plugin settings in SIP002)
        if let queryIndex = workingURI.firstIndex(of: "?") {
            // Note: plugin params not currently used, but strip them
            workingURI = String(workingURI[..<queryIndex])
        }

        var method: String
        var password: String
        var server: String
        var port: Int

        if let atIndex = workingURI.lastIndex(of: "@") {
            // SIP002 format: BASE64@host:port
            let userInfo = String(workingURI[..<atIndex])
            let hostPort = String(workingURI[workingURI.index(after: atIndex)...])

            guard let decoded = base64Decode(userInfo),
                  let colonIndex = decoded.firstIndex(of: ":") else {
                throw ConfigImportError.invalidFormat("Invalid SS userinfo")
            }

            method = String(decoded[..<colonIndex])
            password = String(decoded[decoded.index(after: colonIndex)...])

            let hostPortParts = parseHostPort(hostPort)
            server = hostPortParts.host
            port = hostPortParts.port ?? 8388
        } else {
            // Legacy format: entire thing is base64
            guard let decoded = base64Decode(workingURI) else {
                throw ConfigImportError.invalidFormat("Invalid SS base64")
            }

            // Format: method:password@host:port
            guard let atIndex = decoded.lastIndex(of: "@"),
                  let colonIndex = decoded.firstIndex(of: ":") else {
                throw ConfigImportError.invalidFormat("Invalid SS format")
            }

            method = String(decoded[..<colonIndex])
            let afterMethod = decoded.index(after: colonIndex)
            password = String(decoded[afterMethod..<atIndex])

            let hostPort = String(decoded[decoded.index(after: atIndex)...])
            let hostPortParts = parseHostPort(hostPort)
            server = hostPortParts.host
            port = hostPortParts.port ?? 8388
        }

        let credentialRef = try await storeCredential(password, for: name)

        return Service(
            name: name,
            protocol: .shadowsocks,
            server: server,
            port: port,
            credentialRef: credentialRef,
            settings: ["method": .string(method)]
        )
    }

    // MARK: - VMess

    private func parseVMess(_ uri: String) async throws -> Service? {
        // Format: vmess://BASE64(JSON)
        let base64Part = String(uri.dropFirst(8)) // Remove "vmess://"

        guard let decoded = base64Decode(base64Part),
              let data = decoded.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigImportError.invalidFormat("Invalid VMess base64 JSON")
        }

        let name = json["ps"] as? String ?? json["remarks"] as? String ?? "VMess"
        let server = json["add"] as? String ?? ""
        let port = (json["port"] as? Int) ?? Int(json["port"] as? String ?? "") ?? 443
        let uuid = json["id"] as? String ?? ""

        var settings: [String: AnyCodableValue] = [:]

        if let alterId = json["aid"] as? Int ?? Int(json["aid"] as? String ?? "") {
            settings["alter_id"] = .int(alterId)
        }
        if let security = json["scy"] as? String {
            settings["security"] = .string(security)
        }
        if let network = json["net"] as? String {
            settings["transport_type"] = .string(network)
        }
        if let path = json["path"] as? String {
            settings["transport_path"] = .string(path)
        }
        if let host = json["host"] as? String {
            settings["transport_host"] = .string(host)
        }
        if let tls = json["tls"] as? String {
            settings["tls_enabled"] = .bool(tls == "tls")
        }
        if let sni = json["sni"] as? String {
            settings["tls_server_name"] = .string(sni)
        }

        let credentialRef = try await storeCredential(uuid, for: name)

        return Service(
            name: name,
            protocol: .vmess,
            server: server,
            port: port,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    // MARK: - VLESS

    private func parseVLESS(_ uri: String) async throws -> Service? {
        // Format: vless://UUID@host:port?params#name
        var workingURI = String(uri.dropFirst(8)) // Remove "vless://"

        // Extract fragment (name)
        var name = "VLESS"
        if let hashIndex = workingURI.lastIndex(of: "#") {
            name = String(workingURI[workingURI.index(after: hashIndex)...])
                .removingPercentEncoding ?? name
            workingURI = String(workingURI[..<hashIndex])
        }

        // Extract query params
        var params: [String: String] = [:]
        if let queryIndex = workingURI.firstIndex(of: "?") {
            let queryString = String(workingURI[workingURI.index(after: queryIndex)...])
            params = parseQueryString(queryString)
            workingURI = String(workingURI[..<queryIndex])
        }

        // Parse uuid@host:port
        guard let atIndex = workingURI.firstIndex(of: "@") else {
            throw ConfigImportError.invalidFormat("Invalid VLESS format")
        }

        let uuid = String(workingURI[..<atIndex])
        let hostPort = String(workingURI[workingURI.index(after: atIndex)...])
        let hostPortParts = parseHostPort(hostPort)

        var settings: [String: AnyCodableValue] = [:]

        if let flow = params["flow"] {
            settings["flow"] = .string(flow)
        }
        if let encryption = params["encryption"] {
            settings["encryption"] = .string(encryption)
        }
        if let security = params["security"] {
            settings["tls_enabled"] = .bool(security == "tls" || security == "reality")
            if security == "reality" {
                settings["reality_enabled"] = .bool(true)
            }
        }
        if let sni = params["sni"] {
            settings["tls_server_name"] = .string(sni)
        }
        if let fp = params["fp"] {
            settings["fingerprint"] = .string(fp)
        }
        if let pbk = params["pbk"] {
            settings["reality_public_key"] = .string(pbk)
        }
        if let sid = params["sid"] {
            settings["reality_short_id"] = .string(sid)
        }
        if let type = params["type"] {
            settings["transport_type"] = .string(type)
        }
        if let path = params["path"] {
            settings["transport_path"] = .string(path.removingPercentEncoding ?? path)
        }
        if let host = params["host"] {
            settings["transport_host"] = .string(host)
        }

        let credentialRef = try await storeCredential(uuid, for: name)

        return Service(
            name: name,
            protocol: .vless,
            server: hostPortParts.host,
            port: hostPortParts.port ?? 443,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    // MARK: - Trojan

    private func parseTrojan(_ uri: String) async throws -> Service? {
        // Format: trojan://password@host:port?params#name
        var workingURI = String(uri.dropFirst(9)) // Remove "trojan://"

        // Extract fragment (name)
        var name = "Trojan"
        if let hashIndex = workingURI.lastIndex(of: "#") {
            name = String(workingURI[workingURI.index(after: hashIndex)...])
                .removingPercentEncoding ?? name
            workingURI = String(workingURI[..<hashIndex])
        }

        // Extract query params
        var params: [String: String] = [:]
        if let queryIndex = workingURI.firstIndex(of: "?") {
            let queryString = String(workingURI[workingURI.index(after: queryIndex)...])
            params = parseQueryString(queryString)
            workingURI = String(workingURI[..<queryIndex])
        }

        // Parse password@host:port
        guard let atIndex = workingURI.lastIndex(of: "@") else {
            throw ConfigImportError.invalidFormat("Invalid Trojan format")
        }

        let password = String(workingURI[..<atIndex])
            .removingPercentEncoding ?? String(workingURI[..<atIndex])
        let hostPort = String(workingURI[workingURI.index(after: atIndex)...])
        let hostPortParts = parseHostPort(hostPort)

        var settings: [String: AnyCodableValue] = [:]
        settings["tls_enabled"] = .bool(true) // Trojan always uses TLS

        if let sni = params["sni"] ?? params["peer"] {
            settings["tls_server_name"] = .string(sni)
        }
        if let alpn = params["alpn"] {
            let alpnList = alpn.components(separatedBy: ",")
            settings["tls_alpn"] = .array(alpnList.map { .string($0) })
        }

        let credentialRef = try await storeCredential(password, for: name)

        return Service(
            name: name,
            protocol: .trojan,
            server: hostPortParts.host,
            port: hostPortParts.port ?? 443,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    // MARK: - SOCKS5

    private func parseSOCKS5(_ uri: String) async throws -> Service? {
        // Format: socks5://[user:pass@]host:port#name
        var workingURI = uri
        if workingURI.lowercased().hasPrefix("socks5://") {
            workingURI = String(workingURI.dropFirst(9))
        } else {
            workingURI = String(workingURI.dropFirst(7)) // "socks://"
        }

        // Extract fragment (name)
        var name = "SOCKS5"
        if let hashIndex = workingURI.lastIndex(of: "#") {
            name = String(workingURI[workingURI.index(after: hashIndex)...])
                .removingPercentEncoding ?? name
            workingURI = String(workingURI[..<hashIndex])
        }

        var username: String?
        var password: String?
        var hostPort: String

        if let atIndex = workingURI.lastIndex(of: "@") {
            let userInfo = String(workingURI[..<atIndex])
            hostPort = String(workingURI[workingURI.index(after: atIndex)...])

            if let colonIndex = userInfo.firstIndex(of: ":") {
                username = String(userInfo[..<colonIndex])
                    .removingPercentEncoding
                password = String(userInfo[userInfo.index(after: colonIndex)...])
                    .removingPercentEncoding
            } else {
                username = userInfo.removingPercentEncoding
            }
        } else {
            hostPort = workingURI
        }

        let hostPortParts = parseHostPort(hostPort)
        var settings: [String: AnyCodableValue] = [:]
        var credentialRef: String?

        if let user = username {
            settings["username"] = .string(user)
        }
        if let pass = password {
            credentialRef = try await storeCredential(pass, for: name)
        }

        return Service(
            name: name,
            protocol: .socks5,
            server: hostPortParts.host,
            port: hostPortParts.port ?? 1080,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    // MARK: - Helpers

    private func parseHostPort(_ string: String) -> (host: String, port: Int?) {
        // Handle IPv6: [::1]:port
        if string.hasPrefix("[") {
            if let closeBracket = string.firstIndex(of: "]") {
                let host = String(string[string.index(after: string.startIndex)..<closeBracket])
                let afterBracket = string.index(after: closeBracket)
                if afterBracket < string.endIndex && string[afterBracket] == ":" {
                    let portStr = String(string[string.index(after: afterBracket)...])
                    return (host, Int(portStr))
                }
                return (host, nil)
            }
        }

        // IPv4 or hostname
        if let colonIndex = string.lastIndex(of: ":") {
            let host = String(string[..<colonIndex])
            let portStr = String(string[string.index(after: colonIndex)...])
            return (host, Int(portStr))
        }

        return (string, nil)
    }

    private func parseQueryString(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].removingPercentEncoding ?? parts[0]
                let value = parts[1].removingPercentEncoding ?? parts[1]
                result[key] = value
            }
        }
        return result
    }

    private func base64Decode(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func storeCredential(_ value: String, for tag: String) async throws -> String {
        let ref = await KeychainManager.shared.generateCredentialRef()
        try await KeychainManager.shared.save(value, for: ref)
        return ref
    }
}
