//
//  ClashParser.swift
//  TunnelMaster
//

import Foundation

struct ClashParser: ConfigImporter {
    private let keychainManager: any KeychainManaging

    nonisolated init(keychainManager: any KeychainManaging) {
        self.keychainManager = keychainManager
    }

    func canImport(data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else { return false }
        // Clash configs typically have 'proxies:' section
        return text.contains("proxies:") || text.contains("Proxy:") || text.contains("proxy-groups:")
    }

    func parse(data: Data) async throws -> [Service] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ConfigImportError.invalidEncoding
        }

        // Extract proxies section
        let proxies = try extractProxies(from: text)

        var services: [Service] = []
        for proxy in proxies {
            if let service = try await parseProxy(proxy) {
                services.append(service)
            }
        }

        return services
    }

    // MARK: - YAML Extraction

    private func extractProxies(from yaml: String) throws -> [[String: String]] {
        var proxies: [[String: String]] = []

        // Find proxies section
        guard let proxiesRange = yaml.range(of: "proxies:", options: .caseInsensitive) ??
            yaml.range(of: "Proxy:", options: .caseInsensitive)
        else {
            return []
        }

        let afterProxies = String(yaml[proxiesRange.upperBound...])
        let lines = afterProxies.components(separatedBy: .newlines)

        var currentProxy: [String: String]?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if we've left the proxies section
            // A new top-level section starts at column 0 (no indentation) with a key:value pattern
            let isIndented = line.hasPrefix(" ") || line.hasPrefix("\t")
            if !trimmed.isEmpty, !isIndented, !trimmed.hasPrefix("-"),
               !trimmed.hasPrefix("#"), trimmed.contains(":"), !trimmed.hasPrefix("{") {
                // New top-level section - exit the loop
                break
            }

            // New proxy entry
            if trimmed.hasPrefix("- ") {
                if let proxy = currentProxy {
                    proxies.append(proxy)
                }

                // Check for inline format: - {name: xxx, type: xxx, ...}
                if trimmed.contains("{"), trimmed.contains("}") {
                    if let inlineProxy = parseInlineProxy(trimmed) {
                        proxies.append(inlineProxy)
                        currentProxy = nil
                    }
                } else {
                    currentProxy = [:]
                    // Parse first field if on same line
                    let afterDash = String(trimmed.dropFirst(2))
                    if let (key, value) = parseKeyValue(afterDash) {
                        currentProxy?[key] = value
                    }
                }
            } else if currentProxy != nil, trimmed.contains(":"), !trimmed.hasPrefix("#") {
                if let (key, value) = parseKeyValue(trimmed) {
                    currentProxy?[key] = value
                }
            }
        }

        if let proxy = currentProxy {
            proxies.append(proxy)
        }

        return proxies
    }

    private func parseInlineProxy(_ line: String) -> [String: String]? {
        // Parse: - {name: xxx, type: ss, server: xxx, port: xxx, ...}
        guard let start = line.firstIndex(of: "{"),
              let end = line.lastIndex(of: "}")
        else { return nil }

        let content = String(line[line.index(after: start) ..< end])
        var proxy: [String: String] = [:]

        // Split by comma, handling quoted values
        let pairs = splitByComma(content)
        for pair in pairs {
            if let (key, value) = parseKeyValue(pair) {
                proxy[key] = value
            }
        }

        return proxy.isEmpty ? nil : proxy
    }

    private func splitByComma(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in text {
            if char == "\"" || char == "'", !inQuotes {
                inQuotes = true
                quoteChar = char
                current.append(char)
            } else if char == quoteChar, inQuotes {
                inQuotes = false
                current.append(char)
            } else if char == ",", !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        return result
    }

    private func parseKeyValue(_ text: String) -> (String, String)? {
        guard let colonIndex = text.firstIndex(of: ":") else { return nil }

        let key = String(text[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        var value = String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        // Remove quotes
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }

        return key.isEmpty ? nil : (key, value)
    }

    // MARK: - Proxy Parsing

    private func parseProxy(_ proxy: [String: String]) async throws -> Service? {
        guard let type = proxy["type"]?.lowercased(),
              let proto = mapProtocol(type)
        else { return nil }

        let name = proxy["name"] ?? proto.displayName
        let server = proxy["server"] ?? ""
        let port = Int(proxy["port"] ?? "") ?? proto.defaultPort

        var settings: [String: AnyCodableValue] = [:]
        var credentialRef: String?

        switch proto {
        case .vless:
            if let uuid = proxy["uuid"] {
                credentialRef = try await storeCredential(uuid, for: name)
            }
            if let flow = proxy["flow"] { settings["flow"] = .string(flow) }
            settings.merge(parseClashTLS(proxy)) { _, new in new }
            settings.merge(parseClashTransport(proxy)) { _, new in new }
            settings.merge(parseClashReality(proxy)) { _, new in new }

        case .vmess:
            if let uuid = proxy["uuid"] {
                credentialRef = try await storeCredential(uuid, for: name)
            }
            if let alterId = proxy["alterId"] ?? proxy["alter-id"] {
                settings["alter_id"] = .int(Int(alterId) ?? 0)
            }
            if let cipher = proxy["cipher"] {
                settings["security"] = .string(cipher)
            }
            settings.merge(parseClashTLS(proxy)) { _, new in new }
            settings.merge(parseClashTransport(proxy)) { _, new in new }

        case .trojan:
            if let password = proxy["password"] {
                credentialRef = try await storeCredential(password, for: name)
            }
            settings.merge(parseClashTLS(proxy)) { _, new in new }

        case .shadowsocks:
            if let password = proxy["password"] {
                credentialRef = try await storeCredential(password, for: name)
            }
            if let cipher = proxy["cipher"] {
                settings["method"] = .string(cipher)
            }

        case .socks5:
            if let username = proxy["username"] {
                settings["username"] = .string(username)
            }
            if let password = proxy["password"] {
                credentialRef = try await storeCredential(password, for: name)
            }

        case .wireguard:
            if let privateKey = proxy["private-key"] ?? proxy["privateKey"] {
                credentialRef = try await storeCredential(privateKey, for: name)
            }
            if let publicKey = proxy["public-key"] ?? proxy["publicKey"] {
                settings["peer_public_key"] = .string(publicKey)
            }

        case .hysteria2:
            if let password = proxy["password"] {
                credentialRef = try await storeCredential(password, for: name)
            }
            settings.merge(parseClashTLS(proxy)) { _, new in new }
        }

        return Service(
            name: name,
            protocol: proto,
            server: server,
            port: port,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    private func mapProtocol(_ type: String) -> ProxyProtocol? {
        switch type {
        case "vless": return .vless
        case "vmess": return .vmess
        case "trojan": return .trojan
        case "ss", "shadowsocks": return .shadowsocks
        case "socks5", "socks": return .socks5
        case "wireguard", "wg": return .wireguard
        case "hysteria2", "hy2": return .hysteria2
        default: return nil
        }
    }

    private func parseClashTLS(_ proxy: [String: String]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let tls = proxy["tls"] {
            settings["tls_enabled"] = .bool(tls.lowercased() == "true")
        }
        if let sni = proxy["sni"] ?? proxy["servername"] {
            settings["tls_server_name"] = .string(sni)
        }
        if let skipVerify = proxy["skip-cert-verify"] {
            settings["tls_insecure"] = .bool(skipVerify.lowercased() == "true")
        }
        if let alpn = proxy["alpn"] {
            let alpnList = alpn.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            settings["tls_alpn"] = .array(alpnList.map { .string($0) })
        }

        return settings
    }

    private func parseClashTransport(_ proxy: [String: String]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let network = proxy["network"] {
            settings["transport_type"] = .string(network)
        }
        if let path = proxy["ws-path"] ?? proxy["path"] {
            settings["transport_path"] = .string(path)
        }
        // Note: ws-headers parsing would need more complex handling

        return settings
    }

    private func parseClashReality(_ proxy: [String: String]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let realityPublicKey = proxy["reality-public-key"] ?? proxy["public-key"] {
            settings["reality_enabled"] = .bool(true)
            settings["reality_public_key"] = .string(realityPublicKey)
        }
        if let shortId = proxy["reality-short-id"] ?? proxy["short-id"] {
            settings["reality_short_id"] = .string(shortId)
        }

        return settings
    }

    private func storeCredential(_ value: String, for tag: String) async throws -> String {
        let ref = await keychainManager.generateCredentialRef()
        try await keychainManager.save(value, for: ref)
        return ref
    }
}
