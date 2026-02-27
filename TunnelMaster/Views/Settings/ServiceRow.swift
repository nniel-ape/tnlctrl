//
//  ServiceRow.swift
//  TunnelMaster
//

import SwiftUI

struct ServiceRow: View {
    let service: Service
    var isPinging = false

    var body: some View {
        HStack(spacing: 10) {
            // Protocol icon
            Image(systemName: service.protocol.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 6)

            // Name & Server
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .lineLimit(1)
                Text(verbatim: "\(service.server):\(service.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Protocol badge
            Text(service.protocol.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Latency badge or spinner
            if isPinging {
                ProgressView()
                    .controlSize(.small)
            } else if let latency = service.latency {
                LatencyBadge(ms: latency)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Latency Badge

struct LatencyBadge: View {
    let ms: Int

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var label: String {
        ms < 0 ? "timeout" : "\(ms) ms"
    }

    private var color: Color {
        if ms < 0 { return .gray }
        if ms < 100 { return .green }
        if ms < 300 { return .yellow }
        return .red
    }
}
