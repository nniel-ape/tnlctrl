//
//  AppPickerView.swift
//  tnl_ctrl
//
//  Visual picker for selecting installed applications.
//

import SwiftUI

struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appsProvider = InstalledAppsProvider.shared

    let onSelect: (String, RuleType) -> Void

    @State private var searchText = ""
    @State private var selectedApp: InstalledApp?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 450, height: 500)
        .onAppear {
            appsProvider.loadIfNeeded()
            appsProvider.updateRecentApps()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "app.badge")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("Select Application")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search applications...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Recently used section
                if searchText.isEmpty, !appsProvider.recentApps.isEmpty {
                    sectionHeader("Recently Used")
                    ForEach(appsProvider.recentApps) { app in
                        appRow(app)
                    }
                    Divider()
                        .padding(.vertical, 8)
                }

                // All apps or search results
                if searchText.isEmpty {
                    sectionHeader("All Applications")
                }

                if appsProvider.isLoading {
                    loadingView
                } else {
                    let apps = searchText.isEmpty ? appsProvider.apps : appsProvider.search(searchText)
                    if apps.isEmpty {
                        emptyView
                    } else {
                        ForEach(apps) { app in
                            appRow(app)
                        }
                    }
                }

                // Common apps fallback
                if searchText.isEmpty, appsProvider.apps.isEmpty, !appsProvider.isLoading {
                    sectionHeader("Common Applications")
                    ForEach(InstalledAppsProvider.commonApps, id: \.processName) { app in
                        commonAppRow(name: app.name, processName: app.processName)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isSelected = selectedApp?.id == app.id
        return appRow(
            name: app.name,
            processName: app.processName,
            icon: app.icon,
            isSelected: isSelected
        ) {
            selectedApp = app
        }
    }

    private func commonAppRow(name: String, processName: String) -> some View {
        let isSelected = selectedApp?.processName == processName
        return appRow(
            name: name,
            processName: processName,
            icon: nil,
            isSelected: isSelected
        ) {
            selectedApp = InstalledApp(
                id: processName,
                name: name,
                path: "",
                processName: processName
            )
        }
    }

    private func appRow(
        name: String,
        processName: String,
        icon: NSImage?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app")
                        .font(.title)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .lineLimit(1)
                    Text(processName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading applications...")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No applications found")
                .foregroundStyle(.secondary)
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Manual entry option
            Button {
                dismiss()
            } label: {
                Text("Cancel")
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Rule type picker for selected app
            if selectedApp != nil {
                Menu {
                    Button {
                        if let app = selectedApp {
                            onSelect(app.processName, .processName)
                            dismiss()
                        }
                    } label: {
                        Label("By Process Name", systemImage: "terminal")
                    }

                    Button {
                        if let app = selectedApp, !app.path.isEmpty {
                            onSelect(app.path, .processPath)
                            dismiss()
                        }
                    } label: {
                        Label("By Full Path", systemImage: "folder")
                    }
                    .disabled(selectedApp?.path.isEmpty ?? true)
                } label: {
                    Label("Select", systemImage: "chevron.down")
                }
                .menuStyle(.borderedButton)
            }

            Button {
                if let app = selectedApp {
                    onSelect(app.processName, .processName)
                    dismiss()
                }
            } label: {
                Text("Select")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedApp == nil)
        }
        .padding()
    }
}
