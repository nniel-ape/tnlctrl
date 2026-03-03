//
//  ServersTab.swift
//  tnl_ctrl
//

import SwiftUI

struct ServersTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServerId: UUID?
    @State private var editingServer: Server?
    @State private var showingAddServerSheet = false
    @State private var serverForNewService: Server?
    @State private var serversToDelete: [Server] = []

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
            let serverServices = appState.services.filter { $0.serverId == server.id }
            WizardView(
                server: server,
                usedPorts: Set(serverServices.map(\.port)),
                usedContainerNames: Set(server.containerIds)
            )
            .environment(appState)
        }
        .confirmationDialog(
            "Delete Server\(serversToDelete.count > 1 ? "s" : "")",
            isPresented: Binding(
                get: { !serversToDelete.isEmpty },
                set: { if !$0 { serversToDelete = [] } }
            )
        ) {
            let toDelete = serversToDelete
            let totalServices = toDelete.reduce(0) { acc, srv in
                acc + appState.services.filter { $0.serverId == srv.id }.count
            }
            let serverLabel = "Delete \(toDelete.count) Server\(toDelete.count == 1 ? "" : "s")"
            let containerSuffix = " and \(totalServices) Container\(totalServices == 1 ? "" : "s")"
            Button(
                totalServices > 0 ? serverLabel + containerSuffix : serverLabel,
                role: .destructive
            ) {
                Task {
                    for server in toDelete {
                        await appState.deleteServer(server)
                    }
                }
            }
        } message: {
            let totalServices = serversToDelete.reduce(0) { acc, srv in
                acc + appState.services.filter { $0.serverId == srv.id }.count
            }
            if totalServices > 0 {
                Text("This will stop and remove \(totalServices) Docker container\(totalServices == 1 ? "" : "s"). This cannot be undone.")
            } else {
                Text("Delete \(serversToDelete.count) server\(serversToDelete.count == 1 ? "" : "s")? This cannot be undone.")
            }
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
            let hasServices = appState.services.contains { $0.serverId == server.id }
            if hasServices {
                serversToDelete = [server]
            } else {
                Task { await appState.deleteServer(server) }
            }
        }
    }

    // MARK: - Delete

    private func deleteServers(at offsets: IndexSet) {
        var needConfirmation: [Server] = []
        for index in offsets {
            let server = appState.servers[index]
            let hasServices = appState.services.contains { $0.serverId == server.id }
            if hasServices {
                needConfirmation.append(server)
            } else {
                Task { await appState.deleteServer(server) }
            }
        }
        if !needConfirmation.isEmpty {
            serversToDelete = needConfirmation
        }
    }
}
