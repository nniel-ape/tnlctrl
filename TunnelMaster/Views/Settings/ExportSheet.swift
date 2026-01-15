//
//  ExportSheet.swift
//  TunnelMaster
//
//  UI for exporting services to various formats.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "ExportSheet")

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let services: [Service]
    @Binding var format: ExportFormat
    @State private var includeCredentials = false
    @State private var exportContent = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Services")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // Options
            Form {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }

                Toggle("Include Credentials", isOn: $includeCredentials)
                    .help("Warning: Exported file will contain sensitive data")

                if includeCredentials {
                    Label("Credentials will be included. Keep this file secure!", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .frame(height: 160)

            Divider()

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(exportContent)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 150)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportContent, forType: .string)
                }

                Spacer()

                Button("Save to File...") {
                    saveToFile()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .onAppear { generateExport() }
        .onChange(of: format) { generateExport() }
        .onChange(of: includeCredentials) { generateExport() }
    }

    private func generateExport() {
        let exporter = ConfigExporter()

        switch format {
        case .singbox:
            exportContent = exporter.exportToSingBox(services: services, includeCredentials: includeCredentials)
        case .clash:
            exportContent = exporter.exportToClash(services: services, includeCredentials: includeCredentials)
        case .uris:
            let uris = exporter.exportToURIs(services: services, includeCredentials: includeCredentials)
            exportContent = uris.joined(separator: "\n\n")
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        panel.nameFieldStringValue = "tunnelmaster-export.\(format.fileExtension)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try exportContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    logger.error("Failed to save export: \(error)")
                }
            }
        }
    }
}
