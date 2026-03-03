//
//  GeoSiteBrowserView.swift
//  tnl_ctrl
//
//  Browser for GeoSite categories.
//

import SwiftUI

struct GeoSiteBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: GeoSiteDatabase.GeoSiteCategory?

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
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Select GeoSite Category")
                    .font(.headline)
                Text("Route traffic by site category")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search categories...", text: $searchText)
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
                let categories = GeoSiteDatabase.search(searchText)

                // Group by type
                let services = categories.filter { !$0.id.hasPrefix("category-") && $0.id.count > 2 }
                let countries = categories.filter { $0.id.count == 2 }
                let categoryGroups = categories.filter { $0.id.hasPrefix("category-") }

                if !services.isEmpty {
                    sectionHeader("Services")
                    ForEach(services) { category in
                        categoryRow(category)
                    }
                }

                if !countries.isEmpty {
                    sectionHeader("Countries")
                    ForEach(countries) { category in
                        categoryRow(category)
                    }
                }

                if !categoryGroups.isEmpty {
                    sectionHeader("Categories")
                    ForEach(categoryGroups) { category in
                        categoryRow(category)
                    }
                }

                if categories.isEmpty {
                    emptyView
                }

                // Custom input hint
                if searchText.isEmpty {
                    customInputHint
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

    private func categoryRow(_ category: GeoSiteDatabase.GeoSiteCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .frame(width: 24)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(category.name)
                        Text(category.id)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.teal.opacity(0.1))
                            .foregroundStyle(.teal)
                            .clipShape(Capsule())
                    }
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if selectedCategory?.id == category.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedCategory?.id == category.id ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No categories found")
                .foregroundStyle(.secondary)
            Text("Try searching for a service name")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var customInputHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.orange)
                Text("Tip: You can also type a custom GeoSite category")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Text("GeoSite categories are defined in the sing-box geosite database. Check the documentation for available categories.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Custom input field
            HStack {
                TextField("Or enter custom...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }

            Button("Select") {
                let value = selectedCategory?.id ?? searchText.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    onSelect(value)
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedCategory == nil && searchText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}
