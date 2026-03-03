//
//  ShadowsocksFormSection.swift
//  tnl_ctrl
//

import SwiftUI

struct ShadowsocksFormSection: View {
    @Binding var settings: [String: AnyCodableValue]

    private var plugin: String {
        settings["plugin"]?.stringValue ?? ""
    }

    var body: some View {
        Section {
            Picker("Encryption Method", selection: $settings.string(for: "method", default: "aes-256-gcm")) {
                Text("AES-256-GCM").tag("aes-256-gcm")
                Text("AES-128-GCM").tag("aes-128-gcm")
                Text("ChaCha20-IETF-Poly1305").tag("chacha20-ietf-poly1305")
                Text("2022-Blake3-AES-128-GCM").tag("2022-blake3-aes-128-gcm")
                Text("2022-Blake3-AES-256-GCM").tag("2022-blake3-aes-256-gcm")
                Text("2022-Blake3-ChaCha20-Poly1305").tag("2022-blake3-chacha20-poly1305")
                Text("XChaCha20-IETF-Poly1305").tag("xchacha20-ietf-poly1305")
                Text("None").tag("none")
            }

            Picker("Plugin", selection: $settings.string(for: "plugin")) {
                Text("None").tag("")
                Text("obfs-local").tag("obfs-local")
                Text("v2ray-plugin").tag("v2ray-plugin")
            }

            if !plugin.isEmpty {
                TextField("Plugin Options", text: $settings.string(for: "pluginOpts"))
                    .help("e.g. obfs=http;obfs-host=example.com")
            }

            Toggle("UDP over TCP", isOn: $settings.bool(for: "udpOverTcp"))
        } header: {
            Label("Shadowsocks", systemImage: "moon.fill")
        }
    }
}
