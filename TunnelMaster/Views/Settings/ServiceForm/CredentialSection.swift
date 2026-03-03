//
//  CredentialSection.swift
//  TunnelMaster
//

import SwiftUI

struct CredentialSection: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var isRequired = true
    @State private var isRevealed = false

    var body: some View {
        Section {
            HStack {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $value)
                            .textSelection(.enabled)
                    } else {
                        SecureField(placeholder, text: $value)
                    }
                }
                .labelsHidden()

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isRequired, value.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("\(label) is required")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Label(label, systemImage: "key")
        }
    }
}
