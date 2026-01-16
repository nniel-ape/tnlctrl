//
//  WizardState.swift
//  TunnelMaster
//
//  State management for the server deployment wizard.
//

import Foundation

@Observable
@MainActor
final class WizardState {
    // Step tracking
    var currentStep = 0

    // Preselected server (skips target step when set)
    var preselectedServer: Server?

    // Target selection
    var deploymentTarget: DeploymentTarget = .local
    var sshHost = ""
    var sshPort = 22
    var sshUsername = "root"
    var sshKeyPath = ""

    // MARK: - Computed Steps

    var totalSteps: Int {
        preselectedServer != nil ? 3 : 4
    }

    var minStep: Int {
        preselectedServer != nil ? 1 : 0
    }

    // MARK: - Initializers

    convenience init(server: Server) {
        self.init()
        self.preselectedServer = server
        self.deploymentTarget = server.deploymentTarget
        self.sshHost = server.host
        self.sshPort = server.sshPort
        self.sshUsername = server.sshUsername
        self.sshKeyPath = server.sshKeyPath ?? ""
        self.currentStep = 1 // Skip target step
    }

    // Protocol selection
    var selectedProtocol: ProxyProtocol = .vless {
        didSet {
            // Update default port when protocol changes
            serverPort = selectedProtocol.defaultPort
        }
    }

    // Configuration
    var serverPort = 443
    var useReality = false

    // Hysteria2 specific
    var hysteriaBandwidthUp = "100"
    var hysteriaBandwidthDown = "100"
    var hysteriaObfsEnabled = false
    var hysteriaObfsPassword = ""

    // WireGuard specific
    var wgAdminPassword = ""
    var wgDefaultDNS = "1.1.1.1"

    // Custom naming
    var serviceName = ""
    var serverName = ""

    // Deployment
    var isDeploying = false
    var deploymentProgress: [String] = []
    var deploymentError: String?
    var deployedService: Service?

    // MARK: - Computed Names

    var defaultServiceName: String {
        let host = deploymentTarget == .local ? "Local" : sshHost
        return "\(selectedProtocol.displayName) - \(host.isEmpty ? "Server" : host)"
    }

    var defaultServerName: String {
        deploymentTarget == .local ? "Local" : (sshHost.isEmpty ? "Server" : sshHost)
    }

    var effectiveServiceName: String {
        serviceName.trimmingCharacters(in: .whitespaces).isEmpty ? defaultServiceName : serviceName
    }

    var effectiveServerName: String {
        serverName.trimmingCharacters(in: .whitespaces).isEmpty ? defaultServerName : serverName
    }

    // MARK: - Computed

    var canProceed: Bool {
        switch currentStep {
        case 0: // Target step
            if deploymentTarget == .remote {
                return !sshHost.isEmpty && !sshUsername.isEmpty
            }
            return true
        case 1: // Protocol step
            return true
        case 2: // Configure step
            return serverPort > 0 && serverPort < 65536
        case 3: // Deploy step
            return deployedService != nil
        default:
            return false
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 0: "Select Target"
        case 1: "Choose Protocol"
        case 2: "Configure Server"
        case 3: "Deploy"
        default: ""
        }
    }

    // MARK: - Actions

    func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > minStep {
            currentStep -= 1
        }
    }

    func reset() {
        currentStep = minStep
        preselectedServer = nil
        deploymentTarget = .local
        sshHost = ""
        sshPort = 22
        sshUsername = "root"
        sshKeyPath = ""
        selectedProtocol = .vless
        serverPort = 443
        useReality = false
        // Hysteria2
        hysteriaBandwidthUp = "100"
        hysteriaBandwidthDown = "100"
        hysteriaObfsEnabled = false
        hysteriaObfsPassword = ""
        // WireGuard
        wgAdminPassword = ""
        wgDefaultDNS = "1.1.1.1"
        // Custom naming
        serviceName = ""
        serverName = ""
        // Deployment
        isDeploying = false
        deploymentProgress = []
        deploymentError = nil
        deployedService = nil
    }

    func buildDeploymentSettings() -> DeploymentSettings {
        var settings = DeploymentSettings(
            serverHost: deploymentTarget == .local ? "localhost" : sshHost,
            port: serverPort
        )

        // VLESS Reality
        settings.realityEnabled = useReality

        // Hysteria2
        settings.hysteriaBandwidthUp = hysteriaBandwidthUp
        settings.hysteriaBandwidthDown = hysteriaBandwidthDown
        settings.hysteriaObfsType = hysteriaObfsEnabled ? "salamander" : ""
        settings.hysteriaObfsPassword = hysteriaObfsPassword

        // WireGuard
        settings.wgAdminPassword = wgAdminPassword
        settings.wgDefaultDNS = wgDefaultDNS

        // Custom naming
        settings.serviceName = effectiveServiceName

        return settings
    }

    func log(_ message: String) {
        deploymentProgress.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
}

// MARK: - Deployment Target

enum DeploymentTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case remote

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local: "Local Docker"
        case .remote: "Remote Server (SSH)"
        }
    }

    var description: String {
        switch self {
        case .local: "Deploy to Docker on this Mac"
        case .remote: "Deploy to a remote VPS via SSH"
        }
    }

    var systemImage: String {
        switch self {
        case .local: "desktopcomputer"
        case .remote: "server.rack"
        }
    }
}
