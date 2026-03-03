//
//  AddServerSheet.swift
//  tnl_ctrl
//
//  Simple form for registering a new server without deployment.
//

import SwiftUI

struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    // Form state
    @State private var deploymentTarget: DeploymentTarget = .remote
    @State private var serverName = ""
    @State private var sshHost = ""
    @State private var sshPort = 22
    @State private var sshUsername = "root"
    @State private var sshKeyPath = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Server")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Deployment Target") {
                    Picker("Target", selection: $deploymentTarget) {
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

                if deploymentTarget == .remote {
                    Section("SSH Connection") {
                        TextField("Host", text: $sshHost)
                            .textContentType(.URL)

                        TextField("Port", value: $sshPort, format: .number)

                        TextField("Username", text: $sshUsername)
                            .textContentType(.username)

                        TextField("Private Key Path (optional)", text: $sshKeyPath)
                            .help("Leave empty to use default SSH key")
                    }
                } else {
                    Section("Local Docker") {
                        Text("Services will be deployed to Docker on this Mac.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Server Name") {
                    TextField("Name", text: $serverName, prompt: Text(defaultServerName))
                        .help("Display name for this server")
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    saveServer()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    // MARK: - Computed

    private var defaultServerName: String {
        deploymentTarget == .local ? "Local" : (sshHost.isEmpty ? "Server" : sshHost)
    }

    private var effectiveServerName: String {
        let trimmed = serverName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? defaultServerName : trimmed
    }

    private var canSave: Bool {
        if deploymentTarget == .remote {
            return !sshHost.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    // MARK: - Actions

    private func saveServer() {
        let server = Server(
            name: effectiveServerName,
            host: deploymentTarget == .local ? "localhost" : sshHost,
            sshPort: sshPort,
            sshUsername: sshUsername,
            sshKeyPath: sshKeyPath.isEmpty ? nil : sshKeyPath,
            containerIds: [],
            serviceIds: [],
            status: .unknown,
            deploymentTarget: deploymentTarget
        )
        appState.addServer(server)
        dismiss()
    }
}
