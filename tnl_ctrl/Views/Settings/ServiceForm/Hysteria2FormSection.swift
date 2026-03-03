//
//  Hysteria2FormSection.swift
//  tnl_ctrl
//

import SwiftUI

struct Hysteria2FormSection: View {
    @Binding var settings: [String: AnyCodableValue]

    var body: some View {
        Section {
            TextField("Upload Bandwidth (Mbps)", text: $settings.string(for: "up"))
                .help("Leave empty for auto (BBR congestion control)")

            TextField("Download Bandwidth (Mbps)", text: $settings.string(for: "down"))
                .help("Leave empty for auto (BBR congestion control)")

            TextField("Obfuscation Password (optional)", text: $settings.string(for: "obfs"))
                .help("Salamander obfuscation — leave empty to disable")

            TextField("Port Hopping (optional)", text: $settings.string(for: "serverPorts"))
                .help("Port range for hopping, e.g. 20000-40000")

            TextField("Hop Interval (optional)", text: $settings.string(for: "hopInterval"))
                .help("Port hop interval, e.g. 30s — requires port hopping")
        } header: {
            Label("Hysteria2", systemImage: "hare")
        }
    }
}
