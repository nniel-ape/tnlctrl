//
//  TLSSettingsSection.swift
//  TunnelMaster
//

import SwiftUI

struct TLSSettingsSection: View {
    @Binding var settings: [String: AnyCodableValue]
    var showReality = false

    private static let fingerprints = ["", "chrome", "firefox", "safari", "edge", "ios", "android", "random", "randomized"]

    var body: some View {
        Section {
            Toggle("Enable TLS", isOn: $settings.bool(for: "tls", default: true))

            TextField("SNI (Server Name)", text: $settings.string(for: "sni"))
                .textContentType(.URL)

            TextField("ALPN (comma-separated)", text: $settings.string(for: "alpn"))

            Picker("Fingerprint", selection: $settings.string(for: "fingerprint")) {
                Text("None").tag("")
                Text("Chrome").tag("chrome")
                Text("Firefox").tag("firefox")
                Text("Safari").tag("safari")
                Text("Edge").tag("edge")
                Text("iOS").tag("ios")
                Text("Android").tag("android")
                Text("Random").tag("random")
                Text("Randomized").tag("randomized")
            }

            Toggle("Allow Insecure", isOn: $settings.bool(for: "allowInsecure"))

            Toggle("TLS Fragment", isOn: $settings.bool(for: "fragment"))
                .help("Fragment TLS handshake for censorship bypass")

            if showReality {
                realitySection
            }
        } header: {
            Label("TLS", systemImage: "lock.shield")
        }
    }

    @ViewBuilder private var realitySection: some View {
        Toggle("Reality", isOn: $settings.bool(for: "reality"))

        if settings["reality"]?.boolValue == true {
            TextField("Reality Public Key", text: $settings.string(for: "realityPublicKey"))
            TextField("Reality Short ID", text: $settings.string(for: "realityShortId"))
        }
    }
}
