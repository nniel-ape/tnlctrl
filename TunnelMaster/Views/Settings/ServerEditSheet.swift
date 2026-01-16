//
//  ServerEditSheet.swift
//  TunnelMaster
//

import SwiftUI

struct ServerEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var editedServer: Server
    @State private var sshKeyPathText: String

    private let originalServer: Server

    init(server: Server) {
        self.originalServer = server
        _editedServer = State(initialValue: server)
        _sshKeyPathText = State(initialValue: server.sshKeyPath ?? "")
    }

    private var linkedServices: [Service] {
        appState.services.filter { $0.serverId == originalServer.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Server")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Server") {
                    TextField("Name", text: $editedServer.name)
                        .textFieldStyle(.roundedBorder)

                    LabeledContent("Host") {
                        Text(originalServer.host)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Type") {
                        Text(originalServer.deploymentTarget.displayName)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Created") {
                        Text(originalServer.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                if originalServer.deploymentTarget == .remote {
                    Section("SSH Connection") {
                        TextField("Port", value: $editedServer.sshPort, format: .number)

                        TextField("Username", text: $editedServer.sshUsername)
                            .textContentType(.username)

                        TextField("Private Key Path", text: $sshKeyPathText)
                            .onChange(of: sshKeyPathText) { _, newValue in
                                editedServer.sshKeyPath = newValue.isEmpty ? nil : newValue
                            }
                            .help("Leave empty to use default SSH key")
                    }
                }

                if !linkedServices.isEmpty {
                    Section("Services (\(linkedServices.count))") {
                        ForEach(linkedServices) { service in
                            Label(service.name, systemImage: service.protocol.systemImage)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !originalServer.containerIds.isEmpty {
                    Section("Containers (\(originalServer.containerIds.count))") {
                        ForEach(originalServer.containerIds, id: \.self) { containerId in
                            Text(containerId)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
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

                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasChanges)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
    }

    // MARK: - Helpers

    private var hasChanges: Bool {
        editedServer.name != originalServer.name ||
            editedServer.sshPort != originalServer.sshPort ||
            editedServer.sshUsername != originalServer.sshUsername ||
            editedServer.sshKeyPath != originalServer.sshKeyPath
    }

    private func saveChanges() {
        appState.updateServer(editedServer)
        dismiss()
    }
}
