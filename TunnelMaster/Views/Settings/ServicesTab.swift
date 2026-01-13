//
//  ServicesTab.swift
//  TunnelMaster
//

import SwiftUI

struct ServicesTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.services.isEmpty {
                emptyState
            } else {
                servicesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Services")
                .font(.title2)
            Text("Import a config or deploy a new server to get started.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Import Config...") {
                    // TODO: Task 10 - Import UI
                }
                Button("Add Server...") {
                    // TODO: Task 23 - Deployment wizard
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var servicesList: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(appState.services.count) services")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Import...") {
                    // TODO: Task 10
                }
                Button("Add Server...") {
                    // TODO: Task 23
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // List
            List {
                ForEach(appState.services) { service in
                    ServiceRowPlaceholder(service: service)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        appState.deleteService(appState.services[index])
                    }
                }
            }
        }
    }
}

// Temporary row until Task 10
private struct ServiceRowPlaceholder: View {
    let service: Service

    var body: some View {
        HStack {
            Image(systemName: service.protocol.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(service.name)
                    .font(.headline)
                Text("\(service.server):\(service.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let latency = service.latency {
                Text("\(latency) ms")
                    .font(.caption)
                    .foregroundStyle(latencyColor(latency))
            }

            Toggle("", isOn: .constant(service.isEnabled))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 100 { return .green }
        if ms < 300 { return .yellow }
        return .red
    }
}
