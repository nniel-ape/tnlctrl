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

    init(preselectedServer: Server? = nil) {
        if let server = preselectedServer {
            _wizardState = State(initialValue: WizardState(server: server))
        } else {
            _wizardState = State(initialValue: WizardState())
        }
    }

    private var headerTitle: String {
        if let server = wizardState.preselectedServer {
            return "Add Service to \(server.name)"
        }
        return "Deploy New Server"
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
        case 0:
            TargetStepView(state: wizardState)
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

// MARK: - Target Step

struct TargetStepView: View {
    @Bindable var state: WizardState

    var body: some View {
        Form {
            Section {
                Picker("Deployment Target", selection: $state.deploymentTarget) {
                    ForEach(DeploymentTarget.allCases) { target in
                        HStack {
                            Image(systemName: target.systemImage)
                            VStack(alignment: .leading) {
                                Text(target.displayName)
                                Text(target.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(target)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            if state.deploymentTarget == .remote {
                Section("SSH Connection") {
                    TextField("Host", text: $state.sshHost)
                        .textContentType(.URL)

                    TextField("Port", value: $state.sshPort, format: .number)

                    TextField("Username", text: $state.sshUsername)
                        .textContentType(.username)

                    TextField("Private Key Path (optional)", text: $state.sshKeyPath)
                        .help("Leave empty to use default SSH key")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Protocol Step

struct ProtocolStepView: View {
    @Bindable var state: WizardState

    private let supportedProtocols: [ProxyProtocol] = [.vless, .trojan, .shadowsocks]

    var body: some View {
        Form {
            Section("Select Protocol") {
                Picker("Protocol", selection: $state.selectedProtocol) {
                    ForEach(supportedProtocols, id: \.self) { proto in
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
            Section("Server Configuration") {
                TextField("Port", value: $state.serverPort, format: .number)
                    .help("Port for the proxy server")

                if state.selectedProtocol == .vless {
                    Toggle("Enable Reality", isOn: $state.useReality)
                        .help("VLESS Reality provides better camouflage")
                }
            }

            Section("Generated Credentials") {
                let settings = state.buildDeploymentSettings()
                LabeledContent("UUID / Password", value: settings.uuid.prefix(8) + "...")
                LabeledContent("Container Name", value: settings.containerName)
            }
        }
        .formStyle(.grouped)
        .padding()
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

            if let existingServer = state.preselectedServer {
                // Deploy to existing server
                let service = try await deployer.deployToExisting(server: existingServer)
                state.deployedService = service
                appState.addService(service)

                // Update existing server's serviceIds and containerIds
                var updatedServer = existingServer
                updatedServer.serviceIds.append(service.id)
                updatedServer.containerIds.append(state.buildDeploymentSettings().containerName)
                appState.updateServer(updatedServer)
            } else {
                // Deploy new server
                let (service, server) = try await deployer.deploy()
                state.deployedService = service
                appState.addService(service)
                appState.addServer(server)
            }
        } catch {
            state.deploymentError = error.localizedDescription
        }

        state.isDeploying = false
    }
}
