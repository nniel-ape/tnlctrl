//
//  ImportLinkSheet.swift
//  tnl_ctrl
//
//  Sheet for importing a single proxy share link.
//

import SwiftUI

struct ImportLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var linkText = ""
    @State private var errorMessage: String?
    @State private var isImporting = false

    private var canImport: Bool {
        !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(minWidth: 480, maxWidth: 480, minHeight: 220, idealHeight: 260)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Import from Link")
                    .font(.headline)
                Text("Paste a share link (vless, vmess, trojan, ss, socks5, hysteria2)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $linkText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.link)

                Spacer()
            }

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                Task { await importLink() }
            } label: {
                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Import")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canImport)
        }
        .padding()
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            linkText = string
            errorMessage = nil
        }
    }

    private func importLink() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isImporting = true
        defer { isImporting = false }
        errorMessage = nil

        guard let result = LinkParser.parse(trimmed) else {
            errorMessage = "Unrecognised or invalid link format."
            return
        }

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
        dismiss()
    }
}
