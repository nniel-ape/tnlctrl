//
//  DomainInputView.swift
//  TunnelMaster
//
//  Smart domain input with suggestions and match type selection.
//

import SwiftUI

struct DomainInputView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String, RuleType) -> Void

    private let domainTypes: [RuleType] = [.domain, .domainSuffix, .domainKeyword]

    @State private var domainText = ""
    @State private var matchType: RuleType = .domainSuffix
    @State private var suggestions: [DomainSuggestion] = []
    @State private var selectedCategory: DomainCategory?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            matchTypeSelector
            Divider()
            inputSection
            Divider()
            suggestionsSection
            Divider()
            footer
        }
        .frame(width: 450, height: 520)
        .sheet(item: $selectedCategory) { category in
            CategoryBrowserSheet(category: category) { domain in
                domainText = domain
                selectedCategory = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.purple)
            Text("Add Domain Rule")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Match Type Selector

    private var matchTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Match Type", selection: $matchType) {
                ForEach(domainTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Text(matchTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var matchTypeDescription: String {
        switch matchType {
        case .domain:
            "Exact match only (e.g., 'example.com' won't match 'www.example.com')"
        case .domainSuffix:
            "Matches domain and all subdomains (e.g., 'example.com' matches 'www.example.com')"
        case .domainKeyword:
            "Matches any domain containing the keyword (e.g., 'google' matches 'google.com', 'googleapis.com')"
        default:
            ""
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(matchType.placeholder, text: $domainText)
                    .textFieldStyle(.plain)
                    .onChange(of: domainText) { _, newValue in
                        updateSuggestions(for: newValue)
                    }
                if !domainText.isEmpty {
                    Button {
                        domainText = ""
                        suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Preview
            if !domainText.isEmpty {
                matchPreview
            }
        }
        .padding()
    }

    private var matchPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Will match:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(previewExamples, id: \.self) { example in
                    Text(example)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var previewExamples: [String] {
        let value = domainText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return [] }

        switch matchType {
        case .domain:
            return [value]
        case .domainSuffix:
            return [value, "www.\(value)", "api.\(value)"]
        case .domainKeyword:
            return ["\(value).com", "www.\(value).net", "api.\(value).io"]
        default:
            return []
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !suggestions.isEmpty {
                    sectionHeader("Suggestions")
                    ForEach(suggestions.prefix(10)) { suggestion in
                        suggestionRow(suggestion)
                    }
                } else if domainText.isEmpty {
                    // Show categories
                    sectionHeader("Popular Categories")
                    categoryGrid
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

    private func suggestionRow(_ suggestion: DomainSuggestion) -> some View {
        Button {
            domainText = suggestion.domain
        } label: {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .frame(width: 24)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name)
                        .lineLimit(1)
                    Text(suggestion.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
            ForEach(DomainSuggestionDatabase.categories) { category in
                categoryCard(category)
            }
        }
        .padding(.horizontal)
    }

    private func categoryCard(_ category: DomainCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
                Text("\(category.domainCount) domains")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Add Rule") {
                let value = domainText.trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    onSelect(value, matchType)
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(domainText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    // MARK: - Helpers

    private func updateSuggestions(for query: String) {
        if query.isEmpty {
            suggestions = []
        } else {
            suggestions = DomainSuggestionDatabase.search(query)
        }
    }
}

// MARK: - Category Browser Sheet

private struct CategoryBrowserSheet: View {
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
