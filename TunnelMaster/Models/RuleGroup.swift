//
//  RuleGroup.swift
//  TunnelMaster
//
//  Organizational containers for routing rules.
//

import Foundation
import SwiftUI

struct RuleGroup: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var icon: String // SF Symbol name
    var color: GroupColor
    var isExpanded: Bool // UI state for collapsible sections
    var position: Int // For manual ordering

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String = "folder",
        color: GroupColor = .blue,
        isExpanded: Bool = true,
        position: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.isExpanded = isExpanded
        self.position = position
    }

    // MARK: - Codable with migration support

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case icon
        case color
        case isExpanded
        case position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "folder"
        self.color = try container.decodeIfPresent(GroupColor.self, forKey: .color) ?? .blue
        self.isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        self.position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
    }
}

// MARK: - Group Color

enum GroupColor: String, Codable, CaseIterable, Sendable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray

    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .gray: return .gray
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
