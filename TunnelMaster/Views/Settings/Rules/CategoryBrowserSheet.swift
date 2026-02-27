//
//  CategoryBrowserSheet.swift
//  TunnelMaster
//

import SwiftUI

struct CategoryBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: DomainCategory
    let onSelect: (String) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            domainList
        }
        .frame(width: 400, height: 450)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(.purple)
            Text(category.name)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search in \(category.name)...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var domainList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filteredDomains) { domain in
                    Button {
                        onSelect(domain.domain)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: domain.icon)
                                .frame(width: 24)
                                .foregroundStyle(.purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(domain.name)
                                Text(domain.domain)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredDomains: [DomainSuggestion] {
        if searchText.isEmpty {
            category.domains
        } else {
            category.domains.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.domain.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
