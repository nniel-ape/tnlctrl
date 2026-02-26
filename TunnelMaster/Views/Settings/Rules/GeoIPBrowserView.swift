//
//  GeoIPBrowserView.swift
//  TunnelMaster
//
//  Browser for selecting country codes for GeoIP rules.
//

import SwiftUI

struct GeoIPBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCountry: CountryCodeDatabase.Country?

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
        .frame(width: 400, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "flag")
                .font(.title2)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Select Country")
                    .font(.headline)
                Text("Route traffic by destination country")
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
            TextField("Search countries...", text: $searchText)
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
                let countries = CountryCodeDatabase.search(searchText)

                ForEach(countries) { country in
                    countryRow(country)
                }

                if countries.isEmpty {
                    emptyView
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func countryRow(_ country: CountryCodeDatabase.Country) -> some View {
        Button {
            selectedCountry = country
        } label: {
            HStack(spacing: 12) {
                Text(country.flag)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                    Text(country.code)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.teal.opacity(0.1))
                        .foregroundStyle(.teal)
                        .clipShape(Capsule())
                        .fontDesign(.monospaced)
                }

                Spacer()

                if selectedCountry?.code == country.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedCountry?.code == country.code ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No countries found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Custom input
            HStack {
                TextField("Or enter code...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .textCase(.uppercase)
            }

            Button("Select") {
                let code = selectedCountry?.code ?? searchText.uppercased().trimmingCharacters(in: .whitespaces)
                if !code.isEmpty {
                    onSelect(code)
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedCountry == nil && searchText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}
