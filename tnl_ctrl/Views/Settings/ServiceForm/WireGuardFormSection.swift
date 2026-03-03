//
//  WireGuardFormSection.swift
//  tnl_ctrl
//

import SwiftUI

struct WireGuardFormSection: View {
    @Binding var settings: [String: AnyCodableValue]
    @State private var mtuText = ""

    var body: some View {
        Section {
            TextField("Peer Public Key", text: $settings.string(for: "publicKey"))

            TextField("Pre-Shared Key (optional)", text: $settings.string(for: "preSharedKey"))

            TextField("Local Address IPv4", text: $settings.string(for: "localAddressIPv4"))
                .help("e.g. 10.0.0.2/32")

            TextField("Local Address IPv6 (optional)", text: $settings.string(for: "localAddressIPv6"))
                .help("e.g. fd00::2/128")

            TextField("Reserved (optional)", text: $settings.string(for: "reserved"))
                .help("Comma-separated integers, e.g. 0,0,0")

            TextField("MTU", text: $mtuText)
                .onAppear {
                    mtuText = String(settings["mtu"]?.intValue ?? 1420)
                }
                .onChange(of: mtuText) { _, newValue in
                    if let val = Int(newValue), val >= 1280, val <= 1500 {
                        settings["mtu"] = .int(val)
                    }
                }
        } header: {
            Label("WireGuard", systemImage: "lock.shield.fill")
        }
    }
}
