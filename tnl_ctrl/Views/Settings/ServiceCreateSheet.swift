//
//  ServiceCreateSheet.swift
//  tnl_ctrl
//
//  Two-phase service creation: protocol picker → form.
//

import SwiftUI

struct ServiceCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var selectedProtocol: ProxyProtocol = .vless
    @State private var protocolSelected = false

    @State private var name = ""
    @State private var server = ""
    @State private var portText = ""
    @State private var settings: [String: AnyCodableValue] = ProxyProtocol.vless.defaultSettings
    @State private var credentialValue = ""
    @State private var isSaving = false

    @State private var showTLSSection = false
    @State private var showTransportSection = false
    @State private var hasInteracted = false

    // MARK: - Protocol Capabilities

    private var supportsTLS: Bool {
        [.vless, .vmess, .trojan, .hysteria2].contains(selectedProtocol)
    }

    private var supportsTransport: Bool {
        [.vless, .vmess, .trojan].contains(selectedProtocol)
    }

    private var supportsReality: Bool {
        selectedProtocol == .vless
    }

    private var credentialLabel: String {
        switch selectedProtocol {
        case .vless, .vmess: "UUID"
        case .wireguard: "Private Key"
        default: "Password"
        }
    }

    private var credentialPlaceholder: String {
        switch selectedProtocol {
        case .vless, .vmess: "e.g. 12345678-abcd-efgh-ijkl-123456789abc"
        case .wireguard: "Base64-encoded private key"
        default: "Enter password"
        }
    }

    private var credentialRequired: Bool {
        selectedProtocol != .socks5
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if protocolSelected {
                formContent
            } else {
                protocolPickerView
            }
            Divider()
            footer
        }
        .frame(minWidth: 500, maxWidth: 500, minHeight: 400, idealHeight: 600, maxHeight: 800)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedProtocol.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("New Service")
                    .font(.headline)

                if protocolSelected {
                    Text(selectedProtocol.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Choose a protocol")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Protocol Picker (Phase 1)

    private var protocolPickerView: some View {
        ScrollView {
            let columns = [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ProxyProtocol.allCases) { proto in
                    Button {
                        selectedProtocol = proto
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: proto.systemImage)
                                .font(.title3)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(proto.displayName)
                                    .font(.body.weight(.medium))
                                Text(proto.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedProtocol == proto
                                ? Color.accentColor.opacity(0.1)
                                : Color.secondary.opacity(0.05)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedProtocol == proto ? Color.accentColor : Color.secondary.opacity(0.2),
                                    lineWidth: selectedProtocol == proto ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    // MARK: - Form (Phase 2)

    private var formContent: some View {
        Form {
            generalSection

            protocolSection

            if supportsTLS || supportsTransport {
                Section {
                    if supportsTLS {
                        Toggle(isOn: $showTLSSection.animation()) {
                            Label("TLS Settings", systemImage: "lock.shield")
                        }
                        .disabled(selectedProtocol == .hysteria2)
                    }
                    if supportsTransport {
                        Toggle(isOn: $showTransportSection.animation()) {
                            Label("Transport Settings", systemImage: "arrow.up.arrow.down")
                        }
                    }
                } header: {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
            }

            if supportsTLS, showTLSSection {
                TLSSettingsSection(
                    settings: $settings,
                    showReality: supportsReality,
                    sniRequired: selectedProtocol == .hysteria2
                )
            }

            if supportsTransport, showTransportSection {
                TransportSettingsSection(settings: $settings)
            }

            CredentialSection(
                label: credentialLabel,
                placeholder: credentialPlaceholder,
                value: $credentialValue,
                isRequired: credentialRequired,
                showGenerateButton: [.vless, .vmess].contains(selectedProtocol)
            )
        }
        .formStyle(.grouped)
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            TextField("Name", text: $name, prompt: Text(suggestedName))

            TextField("Server", text: $server)
                .textContentType(.URL)
                .onChange(of: server) { _, _ in
                    if !hasInteracted { hasInteracted = true }
                }

            TextField("Port", text: $portText, prompt: Text(String(selectedProtocol.defaultPort)))
                .onChange(of: portText) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { portText = filtered }
                }

            if hasInteracted {
                validationMessages
            }
        } header: {
            Label("General", systemImage: "info.circle")
        }
    }

    // MARK: - Protocol-Specific Section

    @ViewBuilder private var protocolSection: some View {
        switch selectedProtocol {
        case .vless:
            VLESSFormSection(settings: $settings)
        case .vmess:
            VMESSFormSection(settings: $settings)
        case .trojan:
            TrojanFormSection()
        case .shadowsocks:
            ShadowsocksFormSection(settings: $settings)
        case .socks5:
            SOCKS5FormSection(settings: $settings)
        case .wireguard:
            WireGuardFormSection(settings: $settings)
        case .hysteria2:
            Hysteria2FormSection(settings: $settings)
        }
    }

    // MARK: - Validation Messages

    @ViewBuilder private var validationMessages: some View {
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)

        if trimmedServer.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                Text("Server address is required")
                    .font(.caption)
            }
            .foregroundStyle(.red)
        }

        if let port = Int(portText), port < 1 || port > 65535 {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                Text("Port must be 1–65535")
                    .font(.caption)
            }
            .foregroundStyle(.red)
        }

        if selectedProtocol == .hysteria2,
           (settings["sni"]?.stringValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                Text("SNI is required for Hysteria2")
                    .font(.caption)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if protocolSelected {
                Button("Back") {
                    withAnimation { protocolSelected = false }
                }

                Button("Create") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            } else {
                Button("Continue") {
                    settings = selectedProtocol.defaultSettings
                    portText = ""
                    showTLSSection = supportsTLS
                    showTransportSection = false
                    hasInteracted = false
                    withAnimation { protocolSelected = true }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Auto-Name

    private var suggestedName: String {
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        if trimmedServer.isEmpty {
            return "\(selectedProtocol.displayName) Service"
        }
        return "\(selectedProtocol.displayName) @ \(trimmedServer)"
    }

    private var effectiveName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? suggestedName : trimmed
    }

    // MARK: - Validation

    private var parsedPort: Int? {
        if portText.isEmpty { return selectedProtocol.defaultPort }
        guard let port = Int(portText), port > 0, port <= 65535 else { return nil }
        return port
    }

    private var canSave: Bool {
        if isSaving { return false }
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        if trimmedServer.isEmpty { return false }
        if parsedPort == nil { return false }
        if credentialRequired, credentialValue.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if selectedProtocol == .hysteria2,
           (settings["sni"]?.stringValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }

    // MARK: - Save

    private func save() async {
        guard let port = parsedPort else { return }
        isSaving = true
        defer { isSaving = false }

        var credentialRef: String?

        let trimmedCred = credentialValue.trimmingCharacters(in: .whitespaces)
        if !trimmedCred.isEmpty {
            do {
                credentialRef = KeychainManager.shared.generateCredentialRef()
                if let ref = credentialRef {
                    try await KeychainManager.shared.save(trimmedCred, for: ref)
                }
            } catch {
                // Keychain save failed — still save the service
            }
        }

        let service = Service(
            name: effectiveName,
            protocol: selectedProtocol,
            server: server.trimmingCharacters(in: .whitespaces),
            port: port,
            credentialRef: credentialRef,
            settings: settings,
            source: .imported
        )

        appState.addService(service)
        dismiss()
    }
}
