//
//  VLESSFormSection.swift
//  tnl_ctrl
//

import SwiftUI

struct VLESSFormSection: View {
    @Binding var settings: [String: AnyCodableValue]

    var body: some View {
        Section {
            Picker("Flow", selection: $settings.string(for: "flow")) {
                Text("None").tag("")
                Text("xtls-rprx-vision").tag("xtls-rprx-vision")
            }
        } header: {
            Label("VLESS", systemImage: "bolt.shield")
        }
    }
}
