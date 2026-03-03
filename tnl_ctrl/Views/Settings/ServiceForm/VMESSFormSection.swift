//
//  VMESSFormSection.swift
//  tnl_ctrl
//

import SwiftUI

struct VMESSFormSection: View {
    @Binding var settings: [String: AnyCodableValue]
    @State private var alterIdText = ""

    var body: some View {
        Section {
            TextField("Alter ID", text: $alterIdText)
                .onAppear {
                    alterIdText = String(settings["alterId"]?.intValue ?? 0)
                }
                .onChange(of: alterIdText) { _, newValue in
                    if let val = Int(newValue) {
                        settings["alterId"] = .int(val)
                    }
                }

            Picker("Security", selection: $settings.string(for: "security", default: "auto")) {
                Text("Auto").tag("auto")
                Text("AES-128-GCM").tag("aes-128-gcm")
                Text("ChaCha20-Poly1305").tag("chacha20-poly1305")
                Text("None").tag("none")
                Text("Zero").tag("zero")
            }
        } header: {
            Label("VMess", systemImage: "shield.lefthalf.filled")
        }
    }
}
