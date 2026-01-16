//
//  ServersTab.swift
//  TunnelMaster
//

import SwiftUI

struct ServersTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServerId: UUID?
    @State private var editingServer: Server?
    @State private var showingAddServerSheet = false
    @State private var serverForNewService: Server?

    var body: some View {
        Group {
            if appState.servers.isEmpty {
                emptyState
            } else {
                serversContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheet()
                .environment(appState)
        }
        .sheet(item: $editingServer) { server in
            ServerEditSheet(server: server)
                .environment(appState)
        }
        .sheet(item: $serverForNewService) { server in
            WizardView(server: server)
                .environment(appState)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Servers")
                .font(.title2)
            Text("Add a server to start deploying services.")
                .foregroundStyle(.secondary)
            Button("Add Server...") {
                showingAddServerSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Servers Content

    private var serversContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            serversList
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(appState.servers.count) servers")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Add Server...") {
                showingAddServerSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - List

    private var serversList: some View {
        List(selection: $selectedServerId) {
            ForEach(appState.servers) { server in
                ServerRow(
                    server: server,
                    serviceCount: appState.services.filter { $0.serverId == server.id }.count
                )
                .tag(server.id)
            }
            .onDelete(perform: deleteServers)
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .contextMenu(
            forSelectionType: UUID.self,
            menu: { ids in
                if let id = ids.first,
                   let server = appState.servers.first(where: { $0.id == id }) {
                    serverContextMenu(for: server)
                }
            },
            primaryAction: { ids in
                // Double-click opens edit
                if let id = ids.first,
                   let server = appState.servers.first(where: { $0.id == id }) {
                    editingServer = server
                }
            }
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func serverContextMenu(for server: Server) -> some View {
        Button {
            editingServer = server
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            serverForNewService = server
        } label: {
            Label("Deploy Service...", systemImage: "plus.circle")
        }

        Divider()

        Button("Delete", role: .destructive) {
            appState.deleteServer(server)
        }
    }

    // MARK: - Delete

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            appState.deleteServer(appState.servers[index])
        }
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: Server
    let serviceCount: Int

    var body: some View {
        HStack(spacing: 10) {
            // Icon based on deployment target
            Image(systemName: server.deploymentTarget == .local ? "desktopcomputer" : "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 6)

            // Name & Host
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .lineLimit(1)
                Text(server.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Service count badge
            if serviceCount > 0 {
                Text("\(serviceCount) service\(serviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Status badge
            statusBadge
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(server.status.rawValue.capitalized)
                .font(.caption)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusColor: Color {
        switch server.status {
        case .active: .green
        case .stopped: .orange
        case .unknown: .gray
        case .error: .red
        }
    }
}
