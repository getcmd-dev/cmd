// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// TODO: check if we still need this. For now we draw the border with .clear, so there's limited use for this custom shape.

// MARK: - SuggestionBorderShape

/// A shape that draws a border around code completion suggestions.
/// The shape handles the "stepped" outline where the first line may start
/// after an unchanged prefix, creating an L-shaped or stepped polygon.
struct SuggestionBorderShape: Shape {

  init(
    lineGeometries: [LineGeometry],
    lineHeight: CGFloat,
    cornerRadius: CGFloat,
    leadingPadding: CGFloat = 0,
    trailingPadding: CGFloat = 0,
    topPadding: CGFloat = 0,
    bottomPadding: CGFloat = 0)
  {
    self.lineGeometries = lineGeometries
    self.lineHeight = lineHeight
    self.cornerRadius = cornerRadius
    self.leadingPadding = leadingPadding
    self.trailingPadding = trailingPadding
    self.bottomPadding = bottomPadding
    self.topPadding = topPadding
  }

  struct LineGeometry: Equatable {
    /// The x offset where the suggestion content starts on this line.
    let xOffset: CGFloat
    /// The width of the suggestion content on this line.
    let width: CGFloat

    /// The x position where the suggestion ends.
    var xEnd: CGFloat { xOffset + width }
  }

  /// The geometry of each line in the suggestion.
  /// Each entry contains (xOffset, width) where:
  /// - xOffset: The x position where the suggestion starts on this line
  /// - width: The width of the suggestion content on this line
  let lineGeometries: [LineGeometry]

  /// The height of each line.
  let lineHeight: CGFloat

  /// The corner radius for the border.
  let cornerRadius: CGFloat

  let bottomPadding: CGFloat
  let topPadding: CGFloat
  let leadingPadding: CGFloat
  let trailingPadding: CGFloat

  func path(in _: CGRect) -> Path {
    guard !lineGeometries.isEmpty else {
      return Path()
    }

    // If only one line, draw a simple rounded rectangle
    if lineGeometries.count == 1 {
      let geo = lineGeometries[0]
      let rect = CGRect(
        x: geo.xOffset - leadingPadding,
        y: -topPadding,
        width: geo.width + leadingPadding + trailingPadding,
        height: lineHeight + topPadding + bottomPadding)
      return Path(roundedRect: rect, cornerRadius: cornerRadius)
    }

    // For multiple lines, we need to draw a stepped shape
    return buildSteppedPath()
  }

  /// Builds a path for a multi-line stepped shape with rounded corners.
  ///
  /// The shape is traced clockwise:
  /// 1. Start at top-left of first line
  /// 2. Go right along top of first line
  /// 3. Go down the right edge, stepping in/out as line widths change
  /// 4. Go left along bottom of last line
  /// 5. Go up the left edge, stepping in where first line starts further right
  private func buildSteppedPath() -> Path {
    let firstLine = lineGeometries[0]

    // Find the leftmost x position (for lines after the first, or first if it's the leftmost)
    let minXOffset = lineGeometries.map(\.xOffset).min() ?? firstLine.xOffset

    // Build the outline points clockwise
    var points = [CGPoint]()

    // === TOP EDGE ===
    // Top-left corner of first line
    points.append(CGPoint(x: firstLine.xOffset - leadingPadding, y: 0 - topPadding))
    // Top-right corner of first line
    points.append(CGPoint(x: firstLine.xEnd + trailingPadding, y: 0 - topPadding))

    // === RIGHT EDGE (going down) ===
    for (index, geo) in lineGeometries.enumerated() {
      let yBottom =
        if
          index < lineGeometries.count - 1,
          lineGeometries[index + 1].width + lineGeometries[index + 1].xOffset > geo.width + geo.xOffset
        {
          CGFloat(index + 1) * lineHeight - topPadding
        } else {
          CGFloat(index + 1) * lineHeight + bottomPadding
        }

      if index < lineGeometries.count - 1 {
        let nextGeo = lineGeometries[index + 1]

        if nextGeo.xEnd > geo.xEnd {
          // Next line is wider - step out at the TOP of next line
          points.append(CGPoint(x: geo.xEnd + trailingPadding, y: yBottom)) // Go down to bottom of current
          points.append(CGPoint(x: nextGeo.xEnd + trailingPadding, y: yBottom)) // Step right to next line's edge
        } else if nextGeo.xEnd < geo.xEnd {
          // Next line is narrower - step in at the TOP of next line
          points.append(CGPoint(x: geo.xEnd + trailingPadding, y: yBottom)) // Go down to bottom of current (top of next)
          points.append(CGPoint(x: nextGeo.xEnd + trailingPadding, y: yBottom)) // Step left to next line's edge
        }
        // If same width, no point needed - the line continues straight
      } else {
        // Last line - add bottom-right corner
        points.append(CGPoint(x: geo.xEnd + trailingPadding, y: yBottom))
      }
    }

    // === BOTTOM EDGE ===
    let yBottom = points.last?.y ?? 0
    // Bottom-left corner (at the leftmost x of all lines)
    points.append(CGPoint(x: minXOffset - leadingPadding, y: yBottom))

    // === LEFT EDGE (going up) ===
    // Go up to where first line starts (if it starts further right than minXOffset)
    if firstLine.xOffset > minXOffset {
      // Step in at the bottom of first line (top of second line area)
      points.append(CGPoint(x: minXOffset - leadingPadding, y: lineHeight))
      points.append(CGPoint(x: firstLine.xOffset - leadingPadding, y: lineHeight))
    }
    // The path will close back to the starting point (top-left of first line)

    // Now draw the path with rounded corners
    return createRoundedPath(from: points, cornerRadius: cornerRadius)
  }

  /// Creates a path with rounded corners from a list of points.
  private func createRoundedPath(from points: [CGPoint], cornerRadius: CGFloat) -> Path {
    guard points.count >= 3 else {
      return Path()
    }

    var path = Path()

    for i in 0..<points.count {
      let current = points[i]
      let next = points[(i + 1) % points.count]
      let prev = points[(i - 1 + points.count) % points.count]

      // Calculate vectors to previous and next points
      let toPrev = CGPoint(x: prev.x - current.x, y: prev.y - current.y)
      let toNext = CGPoint(x: next.x - current.x, y: next.y - current.y)

      // Calculate distances
      let distToPrev = sqrt(toPrev.x * toPrev.x + toPrev.y * toPrev.y)
      let distToNext = sqrt(toNext.x * toNext.x + toNext.y * toNext.y)

      // Limit corner radius to half the shortest adjacent edge
      let maxRadius = min(distToPrev, distToNext) / 2
      let radius = min(cornerRadius, maxRadius)

      guard radius > 0, distToPrev > 0, distToNext > 0 else {
        if i == 0 {
          path.move(to: current)
        } else {
          path.addLine(to: current)
        }
        continue
      }

      // Calculate the points where the arc starts and ends
      let startPoint = CGPoint(
        x: current.x + (toPrev.x / distToPrev) * radius,
        y: current.y + (toPrev.y / distToPrev) * radius)
      let endPoint = CGPoint(
        x: current.x + (toNext.x / distToNext) * radius,
        y: current.y + (toNext.y / distToNext) * radius)

      if i == 0 {
        path.move(to: startPoint)
      } else {
        path.addLine(to: startPoint)
      }

      // Add the arc
      path.addQuadCurve(to: endPoint, control: current)
    }

    path.closeSubpath()
    return path
  }
}

// MARK: - Preview

#if DEBUG
#Preview("Single Line") {
  SuggestionBorderShape(
    lineGeometries: [
      .init(xOffset: 50, width: 200),
    ],
    lineHeight: 20,
    cornerRadius: 4)
    .stroke(Color.blue, lineWidth: 1)
    .frame(width: 300, height: 30)
    .padding()
}

#Preview("Multi Line - Stepped") {
  SuggestionBorderShape(
    lineGeometries: [
      .init(xOffset: 50, width: 200),
      .init(xOffset: 0, width: 180),
      .init(xOffset: 0, width: 150),
    ],
    lineHeight: 20,
    cornerRadius: 4)
    .stroke(Color.blue, lineWidth: 1)
    .frame(width: 300, height: 70)
    .padding()
}

#Preview("Multi Line - Varying Widths") {
  SuggestionBorderShape(
    lineGeometries: [
      .init(xOffset: 30, width: 150),
      .init(xOffset: 0, width: 200),
      .init(xOffset: 0, width: 100),
      .init(xOffset: 0, width: 180),
    ],
    lineHeight: 20,
    cornerRadius: 4)
    .stroke(Color.blue, lineWidth: 1)
    .frame(width: 300, height: 90)
    .padding()
}
#endif
