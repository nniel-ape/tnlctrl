//
//  ServiceEditSheet.swift
//  TunnelMaster
//

import SwiftUI

struct ServiceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var editedService: Service
    @State private var portText: String

    private let originalService: Service

    init(service: Service) {
        self.originalService = service
        _editedService = State(initialValue: service)
        _portText = State(initialValue: String(service.port))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Service")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("General") {
                    TextField("Name", text: $editedService.name)

                    Picker("Protocol", selection: $editedService.protocol) {
                        ForEach(ProxyProtocol.allCases) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                    .disabled(editedService.source == .created)
                }

                Section("Connection") {
                    TextField("Server", text: $editedService.server)
                        .textContentType(.URL)

                    TextField("Port", text: $portText)
                        .onChange(of: portText) { _, newValue in
                            if let port = Int(newValue), port > 0, port <= 65535 {
                                editedService.port = port
                            }
                        }
                }

                Section("Info") {
                    if let latency = editedService.latency {
                        LabeledContent("Latency", value: "\(latency) ms")
                    }

                    LabeledContent("Source", value: editedService.source == .imported ? "Imported" : "Created")

                    if let serverId = editedService.serverId,
                       let server = appState.servers.first(where: { $0.id == serverId }) {
                        LabeledContent("Server", value: server.name)
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
        .frame(width: 400, height: 450)
    }

    // MARK: - Helpers

    private var hasChanges: Bool {
        editedService.name != originalService.name ||
            editedService.protocol != originalService.protocol ||
            editedService.server != originalService.server ||
            editedService.port != originalService.port
    }

    private func saveChanges() {
        appState.updateService(editedService)
        dismiss()
    }
}
