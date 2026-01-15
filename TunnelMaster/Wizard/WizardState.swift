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
    let totalSteps = 4

    // Target selection
    var deploymentTarget: DeploymentTarget = .local
    var sshHost = ""
    var sshPort = 22
    var sshUsername = "root"
    var sshKeyPath = ""

    // Protocol selection
    var selectedProtocol: ProxyProtocol = .vless

    // Configuration
    var serverPort = 443
    var useReality = false

    // Deployment
    var isDeploying = false
    var deploymentProgress: [String] = []
    var deploymentError: String?
    var deployedService: Service?

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
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    func reset() {
        currentStep = 0
        deploymentTarget = .local
        sshHost = ""
        sshPort = 22
        sshUsername = "root"
        sshKeyPath = ""
        selectedProtocol = .vless
        serverPort = 443
        useReality = false
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
        settings.realityEnabled = useReality
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
