// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// copied from https://stackoverflow.com/a/75757270/2054629

public struct WrappingHStack: Layout {
  public init(horizontalSpacing: CGFloat, verticalSpacing: CGFloat? = nil, alignment: HorizontalAlignment = .leading) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing ?? horizontalSpacing
    self.alignment = alignment
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    guard !subviews.isEmpty else { return .zero }

    let height = subviews.map { $0.sizeThatFits(proposal).height }.max() ?? 0

    var rowWidths = [CGFloat]()
    var currentRowWidth: CGFloat = 0
    for subview in subviews {
      if currentRowWidth + horizontalSpacing + subview.sizeThatFits(proposal).width >= proposal.width ?? 0 {
        rowWidths.append(currentRowWidth)
        currentRowWidth = subview.sizeThatFits(proposal).width
      } else {
        currentRowWidth += horizontalSpacing + subview.sizeThatFits(proposal).width
      }
    }
    rowWidths.append(currentRowWidth)

    let rowCount = CGFloat(rowWidths.count)
    return CGSize(
      width: max(rowWidths.max() ?? 0, proposal.width ?? 0),
      height: rowCount * height + (rowCount - 1) * verticalSpacing)
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    switch alignment {
    case .leading:
      placeSubviewsWithLeadingAlignment(in: bounds, proposal: proposal, subviews: subviews)
    default:
      placeSubviewsWithTrailingAlignment(in: bounds, proposal: proposal, subviews: subviews)
    }
  }

  // inspired by: https://stackoverflow.com/a/75672314
  private let horizontalSpacing: CGFloat
  private let verticalSpacing: CGFloat
  private let alignment: HorizontalAlignment

  private func placeSubviewsWithLeadingAlignment(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews) {
    let height = subviews.map { $0.dimensions(in: proposal).height }.max() ?? 0
    guard !subviews.isEmpty else { return }
    var x = bounds.minX
    var y = height / 2 + bounds.minY
    for subview in subviews {
      x += subview.dimensions(in: proposal).width / 2
      if x + subview.dimensions(in: proposal).width / 2 > bounds.maxX {
        x = bounds.minX + subview.dimensions(in: proposal).width / 2
        y += height + verticalSpacing
      }
      subview.place(
        at: CGPoint(x: x, y: y),
        anchor: .center,
        proposal: ProposedViewSize(
          width: subview.dimensions(in: proposal).width,
          height: subview.dimensions(in: proposal).height))
      x += subview.dimensions(in: proposal).width / 2 + horizontalSpacing
    }
  }

  private func placeSubviewsWithTrailingAlignment(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews) {
    let height = subviews.map { $0.dimensions(in: proposal).height }.max() ?? 0
    guard !subviews.isEmpty else { return }

    // When using a trailing alignment, we need to do two passes:
    // 1. Calculate rows
    // 2. Place subviews right-aligned

    // First pass: calculate rows
    // We need to calculate the rows first because we need to know the width of each row to place the subviews correctly.
    var rows: [[LayoutSubviews.Element]] = []
    var currentRow: [LayoutSubviews.Element] = []
    var currentRowWidth: CGFloat = 0

    for subview in subviews {
      let subviewWidth = subview.dimensions(in: proposal).width
      let spacingWidth = currentRow.isEmpty ? 0 : horizontalSpacing

      if currentRowWidth + spacingWidth + subviewWidth > bounds.width, !currentRow.isEmpty {
        rows.append(currentRow)
        currentRow = [subview]
        currentRowWidth = subviewWidth
      } else {
        currentRow.append(subview)
        currentRowWidth += spacingWidth + subviewWidth
      }
    }

    if !currentRow.isEmpty {
      rows.append(currentRow)
    }

    // Second pass: place subviews right-aligned
    var y = height / 2 + bounds.minY

    for row in rows {
      var x = bounds.maxX

      // Place items from right to left
      for subview in row.reversed() {
        let subviewWidth = subview.dimensions(in: proposal).width
        x -= subviewWidth / 2

        subview.place(
          at: CGPoint(x: x, y: y),
          anchor: .center,
          proposal: ProposedViewSize(
            width: subviewWidth,
            height: subview.dimensions(in: proposal).height))

        x -= subviewWidth / 2 + horizontalSpacing
      }

      y += height + verticalSpacing
    }
  }

}
