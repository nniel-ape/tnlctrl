//
//  SettingsPlaceholder.swift
//  TunnelMaster
//

import SwiftUI

struct SettingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title)
            Text("Coming in Task 5")
                .foregroundStyle(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}
