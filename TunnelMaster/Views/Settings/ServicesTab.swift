//
//  ServicesTab.swift
//  TunnelMaster
//

import SwiftUI

struct ServicesTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServiceId: UUID?
    @State private var editingService: Service?
    @State private var showingImportSheet = false
    @State private var showingAddServerSheet = false
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .singbox
    @State private var serverForNewService: Server?

    var body: some View {
        Group {
            if appState.services.isEmpty {
                emptyState
            } else {
                servicesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingImportSheet) {
            ImportSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(services: appState.services, format: $exportFormat)
        }
        .sheet(item: $editingService) { service in
            ServiceEditSheet(service: service)
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
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Services")
                .font(.title2)
            Text("Import a config or deploy a service to a server.")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Import Config...") {
                    showingImportSheet = true
                }
                if appState.servers.isEmpty {
                    Button("Add Server...") {
                        showingAddServerSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Menu("Deploy Service...") {
                        ForEach(appState.servers) { server in
                            Button("to \(server.name)") {
                                serverForNewService = server
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    // MARK: - Services Content

    private var servicesContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            servicesList
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(appState.services.count) services")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Export...") {
                showingExportSheet = true
            }
            Button("Import...") {
                showingImportSheet = true
            }
            Menu {
                Button("Add Server...") {
                    showingAddServerSheet = true
                }
                if !appState.servers.isEmpty {
                    Divider()
                    Menu("Deploy Service...") {
                        ForEach(appState.servers) { server in
                            Button("to \(server.name)") {
                                serverForNewService = server
                            }
                        }
                    }
                }
            } label: {
                Text("Add...")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - List with Sections

    private var servicesList: some View {
        List(selection: $selectedServiceId) {
            // Created Services Section (only show if not empty)
            if !appState.createdServices.isEmpty {
                sectionHeader(
                    title: "Created", count: appState.createdServices.count,
                    systemImage: "server.rack"
                )

                ForEach(appState.createdServices) { service in
                    ServiceRow(service: service)
                        .tag(service.id)
                }
                .onMove(perform: moveCreatedServices)
                .onDelete(perform: deleteCreatedServices)
            }

            // Imported Services Section (only show if not empty)
            if !appState.importedServices.isEmpty {
                sectionHeader(
                    title: "Imported", count: appState.importedServices.count,
                    systemImage: "arrow.down.doc"
                )

                ForEach(appState.importedServices) { service in
                    ServiceRow(service: service)
                        .tag(service.id)
                }
                .onMove(perform: moveImportedServices)
                .onDelete(perform: deleteImportedServices)
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .contextMenu(
            forSelectionType: UUID.self,
            menu: { ids in
                if let id = ids.first,
                   let service = appState.services.first(where: { $0.id == id }) {
                    serviceContextMenu(for: service)
                }
            },
            primaryAction: { ids in
                // Double-click opens edit
                if let id = ids.first,
                   let service = appState.services.first(where: { $0.id == id }) {
                    editingService = service
                }
            }
        )
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int, systemImage: String) -> some View {
        Label("\(title) (\(count))", systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .listRowBackground(Color.clear)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func serviceContextMenu(for service: Service) -> some View {
        Button {
            editingService = service
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button("Test Latency") {
            // TODO: Task 19 - Latency testing
        }

        // Deploy another service to the same server (for created services)
        if let serverId = service.serverId,
           let server = appState.servers.first(where: { $0.id == serverId }) {
            Divider()
            Button {
                serverForNewService = server
            } label: {
                Label("Deploy Service to \(server.name)", systemImage: "plus.circle")
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            appState.deleteService(service)
        }
    }

    // MARK: - Move / Delete Actions

    private func moveCreatedServices(from source: IndexSet, to destination: Int) {
        var created = appState.createdServices
        created.move(fromOffsets: source, toOffset: destination)
        appState.services = created + appState.importedServices
        appState.saveServices()
    }

    private func moveImportedServices(from source: IndexSet, to destination: Int) {
        var imported = appState.importedServices
        imported.move(fromOffsets: source, toOffset: destination)
        appState.services = appState.createdServices + imported
        appState.saveServices()
    }

    private func deleteCreatedServices(at offsets: IndexSet) {
        let created = appState.createdServices
        for index in offsets {
            appState.deleteService(created[index])
        }
    }

    private func deleteImportedServices(at offsets: IndexSet) {
        let imported = appState.importedServices
        for index in offsets {
            appState.deleteService(imported[index])
        }
    }
}

// MARK: - Service Row

struct ServiceRow: View {
    let service: Service

    var body: some View {
        HStack(spacing: 10) {
            // Protocol icon
            Image(systemName: service.protocol.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 6)

            // Name & Server
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .lineLimit(1)
                Text(verbatim: "\(service.server):\(service.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Protocol badge
            Text(service.protocol.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Latency badge (if available)
            if let latency = service.latency {
                LatencyBadge(ms: latency)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Latency Badge

struct LatencyBadge: View {
    let ms: Int

    var body: some View {
        Text("\(ms) ms")
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var color: Color {
        if ms < 100 { return .green }
        if ms < 300 { return .yellow }
        return .red
    }
}
