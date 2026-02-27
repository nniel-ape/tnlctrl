//
//  DeployStepView.swift
//  TunnelMaster
//

import SwiftUI

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
            if let containerName = service.settings["containerName"]?.stringValue {
                updatedServer.containerIds.append(containerName)
            }
            appState.updateServer(updatedServer)
        } catch {
            state.deploymentError = error.localizedDescription
        }

        state.isDeploying = false
    }
}
