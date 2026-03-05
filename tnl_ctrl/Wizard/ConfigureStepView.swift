//
//  ConfigureStepView.swift
//  tnl_ctrl
//

import SwiftUI

struct ConfigureStepView: View {
    @Bindable var state: WizardState

    var body: some View {
        Form {
            Section("Names") {
                TextField("Service Name", text: $state.serviceName, prompt: Text(state.defaultServiceName))
                    .help("Display name for this proxy service")
            }

            Section("Server Configuration") {
                TextField("Port", value: $state.serverPort, format: .number)
                    .help("Port for the proxy server")

                // VLESS-specific options
                if state.selectedProtocol == .vless {
                    Toggle("Enable Reality", isOn: $state.useReality)
                        .help("VLESS Reality provides better camouflage")
                }

                // Hysteria2-specific options
                if state.selectedProtocol == .hysteria2 {
                    hysteria2ConfigSection
                }

                // WireGuard-specific options
                if state.selectedProtocol == .wireguard {
                    wireguardConfigSection
                }
            }

            Section("Generated Credentials") {
                let settings = state.buildDeploymentSettings()

                if state.selectedProtocol == .wireguard {
                    LabeledContent("Container Name", value: settings.containerName)
                    Text("Client configuration will be available from the wg-easy web interface.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("UUID / Password", value: settings.uuid.prefix(8) + "...")
                    LabeledContent("Container Name", value: settings.containerName)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Hysteria2 Configuration

    @ViewBuilder private var hysteria2ConfigSection: some View {
        TextField("Domain (SNI)", text: $state.hysteriaDomain)
            .textContentType(.URL)
            .help("Domain for TLS — required for Hysteria2 (QUIC)")

        Divider()
            .padding(.vertical, 4)

        Text("Bandwidth Limits")
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack {
            TextField("Upload (Mbps)", text: $state.hysteriaBandwidthUp)
                .frame(width: 120)
            TextField("Download (Mbps)", text: $state.hysteriaBandwidthDown)
                .frame(width: 120)
        }
        .help("Client bandwidth limits in Mbps")

        Toggle("Enable Obfuscation", isOn: $state.hysteriaObfsEnabled)
            .help("Salamander obfuscation to disguise QUIC traffic")

        if state.hysteriaObfsEnabled {
            TextField("Obfuscation Password", text: $state.hysteriaObfsPassword)
                .help("Password for salamander obfuscation")
        }
    }

    // MARK: - WireGuard Configuration

    @ViewBuilder private var wireguardConfigSection: some View {
        Divider()
            .padding(.vertical, 4)

        Text("Web Admin Interface")
            .font(.caption)
            .foregroundStyle(.secondary)

        SecureField("Admin Password (optional)", text: $state.wgAdminPassword)
            .help("Password for the wg-easy web interface")

        TextField("Default DNS", text: $state.wgDefaultDNS)
            .help("DNS servers for WireGuard clients")

        Text("Web UI will be available at port 51821")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
