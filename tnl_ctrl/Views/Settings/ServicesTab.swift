//
//  ServicesTab.swift
//  tnl_ctrl
//

import SwiftUI
import UniformTypeIdentifiers

struct ServicesTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServiceId: UUID?
    @State private var editingService: Service?
    @State private var showingCreateSheet = false
    @State private var showingAddServerSheet = false
    @State private var showingImportLinkSheet = false
    @State private var serverForNewService: Server?
    @State private var pingAllTask: Task<Void, Never>?
    @State private var servicesToDelete: [Service] = []
    @State private var createdServices: [Service] = []
    @State private var importedServices: [Service] = []
    @State private var fileImportResults: (results: [LinkParser.ParseResult], errors: [String])?
    private let latencyTester = LatencyTester.shared

    var body: some View {
        Group {
            if appState.services.isEmpty {
                emptyState
            } else {
                servicesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheet()
                .environment(appState)
        }
        .sheet(item: $editingService) { service in
            ServiceEditSheet(service: service)
                .environment(appState)
        }
        .sheet(isPresented: $showingCreateSheet) {
            ServiceCreateSheet()
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
        .sheet(isPresented: $showingImportLinkSheet) {
            ImportLinkSheet()
                .environment(appState)
        }
        .confirmationDialog(
            "Import Services",
            isPresented: Binding(
                get: { fileImportResults != nil },
                set: { if !$0 { fileImportResults = nil } }
            )
        ) {
            if let results = fileImportResults {
                Button("Import \(results.results.count) Service(s)") {
                    Task {
                        await applyFileImport(results: results)
                    }
                }
            }
        } message: {
            if let results = fileImportResults {
                Text(fileImportMessage(for: results))
            }
        }
        .onAppear { recomputeServiceSections() }
        .onChange(of: appState.services) { _, _ in recomputeServiceSections() }
        .confirmationDialog(
            "Delete Service\(servicesToDelete.count > 1 ? "s" : "")",
            isPresented: Binding(
                get: { !servicesToDelete.isEmpty },
                set: { if !$0 { servicesToDelete = [] } }
            )
        ) {
            let toDelete = servicesToDelete
            Button("Delete and Remove \(toDelete.count) Container\(toDelete.count == 1 ? "" : "s")", role: .destructive) {
                Task {
                    for service in toDelete {
                        await appState.deleteService(service)
                    }
                }
            }
        } message: {
            if servicesToDelete.count == 1, let service = servicesToDelete.first {
                Text("This will stop and remove the Docker container for \"\(service.name)\". This cannot be undone.")
            } else {
                Text("This will stop and remove \(servicesToDelete.count) Docker containers. This cannot be undone.")
            }
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
            Text("Add a service manually or deploy one to a server.")
                .foregroundStyle(.secondary)

            Menu {
                Button("New Service...") {
                    showingCreateSheet = true
                }

                if !appState.servers.isEmpty {
                    Divider()
                    ForEach(appState.servers) { server in
                        Button("Deploy to \(server.name)...") {
                            serverForNewService = server
                        }
                    }
                }

                Divider()

                Button("Import from Link...") {
                    showingImportLinkSheet = true
                }
                Button("Import from File...") {
                    performImportFromFile()
                }

                Divider()

                Button("Add Server...") {
                    showingAddServerSheet = true
                }
            } label: {
                Text("Add...")
            }
            .buttonStyle(.borderedProminent)
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

            if latencyTester.isPingingAll {
                ProgressView()
                    .controlSize(.small)
                Text("Pinging...")
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    pingAll()
                } label: {
                    Label("Ping All", systemImage: "bolt.horizontal")
                }
            }

            Menu {
                Button("New Service...") {
                    showingCreateSheet = true
                }

                if !appState.servers.isEmpty {
                    Divider()
                    ForEach(appState.servers) { server in
                        Button("Deploy to \(server.name)...") {
                            serverForNewService = server
                        }
                    }
                }

                Divider()

                Button("Import from Link...") {
                    showingImportLinkSheet = true
                }
                Button("Import from File...") {
                    performImportFromFile()
                }

                Divider()

                Button("Add Server...") {
                    showingAddServerSheet = true
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
            if !createdServices.isEmpty {
                sectionHeader(
                    title: "Created",
                    count: createdServices.count,
                    systemImage: "server.rack"
                )

                ForEach(createdServices) { service in
                    ServiceRow(
                        service: service,
                        isPinging: latencyTester.pingingServiceIds.contains(service.id)
                    )
                    .tag(service.id)
                }
                .onMove(perform: moveCreatedServices)
                .onDelete(perform: deleteCreatedServices)
            }

            // Imported Services Section (only show if not empty)
            if !importedServices.isEmpty {
                sectionHeader(
                    title: "Imported",
                    count: importedServices.count,
                    systemImage: "arrow.down.doc"
                )

                ForEach(importedServices) { service in
                    ServiceRow(
                        service: service,
                        isPinging: latencyTester.pingingServiceIds.contains(service.id)
                    )
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
            Task {
                let result = await latencyTester.testLatency(for: service)
                if let index = appState.services.firstIndex(where: { $0.id == service.id }) {
                    switch result {
                    case let .success(ms):
                        appState.services[index].latency = ms
                    case .timeout, .error:
                        appState.services[index].latency = -1
                    }
                    appState.saveServices()
                }
            }
        }
        .disabled(latencyTester.pingingServiceIds.contains(service.id))

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
            if service.source == .created {
                servicesToDelete = [service]
            } else {
                Task { await appState.deleteService(service) }
            }
        }
    }

    // MARK: - Ping All

    private func pingAll() {
        pingAllTask?.cancel()
        pingAllTask = Task {
            await latencyTester.testAll(services: appState.services) { id, result in
                guard !Task.isCancelled else { return }
                if let index = appState.services.firstIndex(where: { $0.id == id }) {
                    switch result {
                    case let .success(ms):
                        appState.services[index].latency = ms
                    case .timeout, .error:
                        appState.services[index].latency = -1
                    }
                }
            }
            guard !Task.isCancelled else { return }
            appState.saveServices()
        }
    }

    // MARK: - Service Section Cache

    private func recomputeServiceSections() {
        createdServices = appState.services.filter { $0.source == .created }
        importedServices = appState.services.filter { $0.source == .imported }
    }

    // MARK: - Move / Delete Actions

    private func moveCreatedServices(from source: IndexSet, to destination: Int) {
        var created = createdServices
        created.move(fromOffsets: source, toOffset: destination)
        appState.services = created + importedServices
        appState.saveServices()
    }

    private func moveImportedServices(from source: IndexSet, to destination: Int) {
        var imported = importedServices
        imported.move(fromOffsets: source, toOffset: destination)
        appState.services = createdServices + imported
        appState.saveServices()
    }

    private func deleteCreatedServices(at offsets: IndexSet) {
        let created = createdServices
        var needConfirmation: [Service] = []
        for index in offsets {
            let service = created[index]
            if service.source == .created {
                needConfirmation.append(service)
            } else {
                Task { await appState.deleteService(service) }
            }
        }
        if !needConfirmation.isEmpty {
            servicesToDelete = needConfirmation
        }
    }

    private func deleteImportedServices(at offsets: IndexSet) {
        let imported = importedServices
        for index in offsets {
            Task { await appState.deleteService(imported[index]) }
        }
    }

    // MARK: - Import from File

    private func performImportFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.message = "Select a file containing share links (one per line)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let results = LinkParser.parseBatch(content)

            if results.results.isEmpty {
                let alert = NSAlert()
                alert.messageText = "No Valid Links Found"
                alert.informativeText = "The selected file does not contain any recognisable proxy share links."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                fileImportResults = results
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Read File"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func applyFileImport(results: (results: [LinkParser.ParseResult], errors: [String])) async {
        for result in results.results {
            var service = result.service

            if let credential = result.credential, !credential.isEmpty {
                do {
                    let ref = KeychainManager.shared.generateCredentialRef()
                    try await KeychainManager.shared.save(credential, for: ref)
                    service.credentialRef = ref
                } catch {
                    // Keychain save failed — still import the service
                }
            }

            appState.addService(service)
        }

        fileImportResults = nil
    }

    private func fileImportMessage(for results: (results: [LinkParser.ParseResult], errors: [String])) -> String {
        var counts: [String: Int] = [:]
        for result in results.results {
            let name = result.service.protocol.displayName
            counts[name, default: 0] += 1
        }
        let protocolCounts = counts
            .map { "\($0.value) \($0.key)" }
            .sorted()
            .joined(separator: ", ")

        var message = "Found \(results.results.count) valid service(s): \(protocolCounts)."
        if !results.errors.isEmpty {
            message += " \(results.errors.count) line(s) skipped."
        }
        return message
    }
}
