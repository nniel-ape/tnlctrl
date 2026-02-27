//
//  ServerRow.swift
//  TunnelMaster
//

import SwiftUI

struct ServerRow: View {
    let server: Server
    let serviceCount: Int

    var body: some View {
        HStack(spacing: 10) {
            // Icon based on deployment target
            Image(systemName: server.deploymentTarget == .local ? "desktopcomputer" : "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 6)

            // Name & Host
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .lineLimit(1)
                Text(server.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Service count badge
            if serviceCount > 0 {
                Text("\(serviceCount) service\(serviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Status badge
            statusBadge
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(server.status.rawValue.capitalized)
                .font(.caption)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusColor: Color {
        switch server.status {
        case .active: .green
        case .stopped: .orange
        case .unknown: .gray
        case .error: .red
        }
    }
}
