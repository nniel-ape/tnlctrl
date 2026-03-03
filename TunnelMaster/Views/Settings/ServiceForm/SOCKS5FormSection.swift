//
//  SOCKS5FormSection.swift
//  TunnelMaster
//

import SwiftUI

struct SOCKS5FormSection: View {
    @Binding var settings: [String: AnyCodableValue]

    var body: some View {
        Section {
            TextField("Username (optional)", text: $settings.string(for: "username"))
        } header: {
            Label("SOCKS5", systemImage: "network")
        }
    }
}
