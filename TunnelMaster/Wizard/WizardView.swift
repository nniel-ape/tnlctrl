//
//  WizardView.swift
//  TunnelMaster
//
//  Multi-step wizard for deploying new proxy servers.
//

import SwiftUI

struct WizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var wizardState: WizardState

    init(server: Server) {
        _wizardState = State(initialValue: WizardState(server: server))
    }

    private var headerTitle: String {
        // During configuration/deploy, show the service name being created
        if wizardState.currentStep >= 2 {
            return "Adding \(wizardState.effectiveServiceName) to \(wizardState.server.name)"
        }
        return "Add Service to \(wizardState.server.name)"
    }

    /// Step index for display (0-based relative to visible steps)
    private var displayStepIndex: Int {
        wizardState.currentStep - wizardState.minStep
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView

            Divider()

            // Footer
            footerView
        }
        .frame(width: 550, height: 450)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.semibold)

            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0 ..< wizardState.totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= displayStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Text(wizardState.stepTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder private var contentView: some View {
        switch wizardState.currentStep {
        case 1:
            ProtocolStepView(state: wizardState)
        case 2:
            ConfigureStepView(state: wizardState)
        case 3:
            DeployStepView(state: wizardState, appState: appState, onDismiss: { dismiss() })
        default:
            EmptyView()
        }
    }

    /// Whether Back button should be shown
    private var canGoBack: Bool {
        // Must be past minStep
        guard wizardState.currentStep > wizardState.minStep else { return false }

        // On deploy step: only allow back if not deploying and not yet succeeded
        if wizardState.currentStep == 3 {
            return !wizardState.isDeploying && wizardState.deployedService == nil
        }

        return true
    }

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if canGoBack {
                Button("Back") {
                    wizardState.previousStep()
                }
            }

            Spacer()

            if wizardState.currentStep < 3 {
                Button("Next") {
                    wizardState.nextStep()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!wizardState.canProceed)
            } else if wizardState.deployedService != nil {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

// MARK: - Protocol Step

struct ProtocolStepView: View {
    @Bindable var state: WizardState

    var body: some View {
        Form {
            Section("Select Protocol") {
                Picker("Protocol", selection: $state.selectedProtocol) {
                    ForEach(ProtocolTemplates.deployableProtocols, id: \.self) { proto in
                        HStack {
                            Image(systemName: proto.systemImage)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(proto.displayName)
                                if let template = ProtocolTemplates.template(for: proto) {
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tag(proto)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Configure Step

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

// MARK: - Deploy Step

struct DeployStepView: View {
    @Bindable var state: WizardState
    let appState: AppState
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if state.isDeploying {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Deploying...")
                    .font(.headline)
            } else if let error = state.deploymentError {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)

                Text("Deployment Failed")
                    .font(.headline)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        await deploy()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else if state.deployedService != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)

                Text("Deployment Complete!")
                    .font(.headline)

                Text("Server has been deployed and added to your services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Initial state - start deployment
                Text("Ready to deploy")
                    .font(.headline)

                Button("Start Deployment") {
                    Task {
                        await deploy()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            // Log output
            if !state.deploymentProgress.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(state.deploymentProgress, id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .task {
            // Auto-start deployment when reaching this step
            if !state.isDeploying, state.deployedService == nil, state.deploymentError == nil {
                await deploy()
            }
        }
    }

    private func deploy() async {
        state.isDeploying = true
        state.deploymentError = nil
        state.deploymentProgress = []

        do {
            let deployer = Deployer(state: state)
            let service = try await deployer.deploy(to: state.server)
            state.deployedService = service
            appState.addService(service)

            // Update server's serviceIds and containerIds
            var updatedServer = state.server
            updatedServer.serviceIds.append(service.id)
            updatedServer.containerIds.append(state.buildDeploymentSettings().containerName)
            appState.updateServer(updatedServer)
        } catch {
            state.deploymentError = error.localizedDescription
        }

        state.isDeploying = false
    }
}
