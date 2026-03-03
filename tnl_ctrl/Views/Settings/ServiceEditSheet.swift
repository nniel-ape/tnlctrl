//
//  ServiceEditSheet.swift
//  tnl_ctrl
//

import SwiftUI

struct ServiceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var name: String
    @State private var selectedProtocol: ProxyProtocol
    @State private var server: String
    @State private var portText: String
    @State private var settings: [String: AnyCodableValue]
    @State private var credentialValue = ""
    @State private var originalCredentialValue = ""
    @State private var isSaving = false

    private let originalService: Service?
    private let isCreateMode: Bool

    // MARK: - Init

    /// Edit mode — pass an existing service.
    init(service: Service) {
        self.originalService = service
        self.isCreateMode = false
        _name = State(initialValue: service.name)
        _selectedProtocol = State(initialValue: service.protocol)
        _server = State(initialValue: service.server)
        _portText = State(initialValue: String(service.port))
        _settings = State(initialValue: service.settings)
    }

    /// Create mode — no existing service.
    init() {
        self.originalService = nil
        self.isCreateMode = true
        let defaultProtocol = ProxyProtocol.vless
        _name = State(initialValue: "")
        _selectedProtocol = State(initialValue: defaultProtocol)
        _server = State(initialValue: "")
        _portText = State(initialValue: String(defaultProtocol.defaultPort))
        _settings = State(initialValue: [:])
    }

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
            formContent
            Divider()
            footer
        }
        .frame(width: 480, height: 650)
        .task { await loadCredential() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(isCreateMode ? "New Service" : "Edit Service")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            generalSection

            protocolSection

            if supportsTLS {
                TLSSettingsSection(settings: $settings, showReality: supportsReality)
            }

            if supportsTransport {
                TransportSettingsSection(settings: $settings)
            }

            CredentialSection(
                label: credentialLabel,
                placeholder: credentialPlaceholder,
                value: $credentialValue,
                isRequired: credentialRequired
            )

            if !isCreateMode {
                infoSection
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            TextField("Name", text: $name)

            Picker("Protocol", selection: $selectedProtocol) {
                ForEach(ProxyProtocol.allCases) { proto in
                    Text(proto.displayName).tag(proto)
                }
            }
            .disabled(!isCreateMode && originalService?.source == .created)
            .onChange(of: selectedProtocol) { oldValue, newValue in
                if isCreateMode {
                    settings = [:]
                    credentialValue = ""
                    if portText == String(oldValue.defaultPort) {
                        portText = String(newValue.defaultPort)
                    }
                }
            }

            TextField("Server", text: $server)
                .textContentType(.URL)

            TextField("Port", text: $portText)
                .onChange(of: portText) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { portText = filtered }
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

    // MARK: - Info Section

    private var infoSection: some View {
        Section("Info") {
            if let latency = originalService?.latency {
                LabeledContent("Latency", value: "\(latency) ms")
            }

            LabeledContent("Source", value: originalService?.source == .imported ? "Imported" : "Created")

            if let serverId = originalService?.serverId,
               let srv = appState.servers.first(where: { $0.id == serverId }) {
                LabeledContent("Server", value: srv.name)
            }
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

            Button(isCreateMode ? "Create" : "Save") {
                Task { await save() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding()
    }

    // MARK: - Validation

    private var parsedPort: Int? {
        guard let port = Int(portText), port > 0, port <= 65535 else { return nil }
        return port
    }

    private var canSave: Bool {
        if isSaving { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedServer = server.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty || trimmedServer.isEmpty { return false }
        if parsedPort == nil { return false }
        if credentialRequired, credentialValue.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if !isCreateMode, !hasChanges { return false }
        return true
    }

    private var hasChanges: Bool {
        guard let original = originalService else { return true }
        return name != original.name
            || selectedProtocol != original.protocol
            || server != original.server
            || portText != String(original.port)
            || settings != original.settings
            || credentialValue != originalCredentialValue
    }

    // MARK: - Credential Load

    private func loadCredential() async {
        guard let ref = originalService?.credentialRef, !ref.isEmpty else { return }
        do {
            if let value = try await KeychainManager.shared.get(ref) {
                credentialValue = value
                originalCredentialValue = value
            }
        } catch {
            // Credential not found — leave empty
        }
    }

    // MARK: - Save

    private func save() async {
        guard let port = parsedPort else { return }
        isSaving = true
        defer { isSaving = false }

        var credentialRef = originalService?.credentialRef

        // Save credential to Keychain
        let trimmedCred = credentialValue.trimmingCharacters(in: .whitespaces)
        if !trimmedCred.isEmpty {
            do {
                let ref = credentialRef?.isEmpty == false ? credentialRef : nil
                if ref == nil {
                    credentialRef = KeychainManager.shared.generateCredentialRef()
                }
                if let ref = credentialRef {
                    try await KeychainManager.shared.save(trimmedCred, for: ref)
                }
            } catch {
                // Keychain save failed — still save the service
            }
        }

        let service = Service(
            id: originalService?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            protocol: selectedProtocol,
            server: server.trimmingCharacters(in: .whitespaces),
            port: port,
            credentialRef: credentialRef,
            settings: settings,
            latency: originalService?.latency,
            source: originalService?.source ?? .imported,
            serverId: originalService?.serverId,
            createdAt: originalService?.createdAt ?? Date()
        )

        if isCreateMode {
            appState.addService(service)
        } else {
            appState.updateService(service)
            if appState.tunnelManager.status.isConnected {
                appState.pendingConfigReload = true
            }
        }

        dismiss()
    }
}
