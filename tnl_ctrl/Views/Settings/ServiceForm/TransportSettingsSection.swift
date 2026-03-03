//
//  TransportSettingsSection.swift
//  tnl_ctrl
//

import SwiftUI

struct TransportSettingsSection: View {
    @Binding var settings: [String: AnyCodableValue]

    private var network: String {
        settings["network"]?.stringValue ?? ""
    }

    var body: some View {
        Section {
            Picker("Transport", selection: $settings.string(for: "network")) {
                Text("TCP (Default)").tag("")
                Text("WebSocket").tag("ws")
                Text("gRPC").tag("grpc")
                Text("HTTP/H2").tag("http")
                Text("HTTPUpgrade").tag("httpupgrade")
                Text("QUIC").tag("quic")
            }

            switch network {
            case "ws":
                TextField("WebSocket Path", text: $settings.string(for: "wsPath"))
                TextField("WebSocket Host", text: $settings.string(for: "wsHost"))
                TextField("Early Data Size (optional)", text: $settings.string(for: "wsEarlyData"))
                    .help("0-RTT early data size in bytes, e.g. 2048")
                TextField("Early Data Header (optional)", text: $settings.string(for: "wsEarlyDataHeader"))
                    .help("e.g. Sec-WebSocket-Protocol for Xray compat")
            case "grpc":
                TextField("gRPC Service Name", text: $settings.string(for: "grpcServiceName"))
            case "http", "h2":
                TextField("HTTP Path", text: $settings.string(for: "httpPath"))
                TextField("HTTP Host", text: $settings.string(for: "httpHost"))
            case "httpupgrade":
                TextField("HTTPUpgrade Path", text: $settings.string(for: "httpUpgradePath"))
                TextField("HTTPUpgrade Host", text: $settings.string(for: "httpUpgradeHost"))
            default:
                EmptyView()
            }
        } header: {
            Label("Transport", systemImage: "arrow.up.arrow.down")
        }
    }
}
