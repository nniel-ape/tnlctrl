//
//  RuleDragItem.swift
//  tnl_ctrl
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
    static let ruleDragItem = UTType(exportedAs: "nniel.tnlctrl.ruleDragItem")
    static let tnlctrlConfig = UTType(exportedAs: "nniel.tnlctrl.configBundle")
}
