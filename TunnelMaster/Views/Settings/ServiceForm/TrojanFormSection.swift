//
//  TrojanFormSection.swift
//  TunnelMaster
//

import SwiftUI

/// Trojan has no protocol-specific fields beyond credential + TLS + transport.
/// This is intentionally empty — the shared sections handle everything.
struct TrojanFormSection: View {
    var body: some View {
        EmptyView()
    }
}
