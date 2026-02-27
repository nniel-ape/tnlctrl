//
//  RuleDragItem.swift
//  TunnelMaster
//
//  Transferable type for drag-and-drop reordering in the rules list.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum RuleDragItem: Codable, Transferable, Equatable {
    case rule(UUID)
    case group(UUID)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .ruleDragItem)
    }
}

extension UTType {
    static let ruleDragItem = UTType(exportedAs: "nniel.TunnelMaster.ruleDragItem")
}
