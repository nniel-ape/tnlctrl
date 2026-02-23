//
//  FlowLayout.swift
//  TunnelMaster
//
//  Flow layout for wrapping items horizontally.
//

import SwiftUI

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.replacingUnspecifiedDimensions().width
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for (subview, size) in row.subviews {
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow: [(Subviews.Element, CGSize)] = []
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        let maxWidth = proposal.replacingUnspecifiedDimensions().width

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > maxWidth, !currentRow.isEmpty {
                rows.append(Row(subviews: currentRow, height: currentRowHeight))
                currentRow = []
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRow.append((subview, size))
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if !currentRow.isEmpty {
            rows.append(Row(subviews: currentRow, height: currentRowHeight))
        }

        return rows
    }

    private struct Row {
        let subviews: [(Subviews.Element, CGSize)]
        let height: CGFloat
    }
}
