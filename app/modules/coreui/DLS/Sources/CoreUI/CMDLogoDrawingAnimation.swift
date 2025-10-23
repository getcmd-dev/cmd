// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// An animated view that progressively draws the CMD logo with a smooth visual effect
public struct CMDLogoDrawingAnimation: View {

  public init(size: CGFloat = 16, drawingWindowLength: CGFloat = 0.75) {
    self.size = size
    // Calculate stroke width based on size to match the SVG's 1-unit thickness in a 16x16 viewport
    self.strokeWidth = size / 16.0
    self.drawingWindowLength = drawingWindowLength
  }

  private let size: CGFloat
  private let strokeWidth: CGFloat
  private let drawingWindowLength: CGFloat // Proportion of total path that's visible at once (0.0 to 1.0)
  private let animationDuration: Double = 2

  public var body: some View {
    CMDLogoDrawingAnimationRepresentable(
      size: size,
      strokeWidth: strokeWidth,
      drawingWindowLength: drawingWindowLength,
      animationDuration: animationDuration
    )
    .frame(width: size, height: size)
  }
}

// MARK: - NSViewRepresentable

private struct CMDLogoDrawingAnimationRepresentable: NSViewRepresentable {
  let size: CGFloat
  let strokeWidth: CGFloat
  let drawingWindowLength: CGFloat
  let animationDuration: Double

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer = CALayer()

    // Parse the SVG file and create a continuous path from the line elements
    // The SVG contains lines in a specific order that flows around the logo
    guard let svgURL = Bundle.module.url(forResource: "cmd-logo", withExtension: "svg"),
          let combinedPath = parseCMDLogoSVG(from: svgURL, targetSize: size) else {
      return view
    }

    // Create multiple non-overlapping shape layers to simulate an opacity gradient along the stroke
    // Each layer shows a separate segment of the window with decreasing opacity
    // This creates a fade from 100% opacity at the head (strokeEnd) to 0% at the tail (strokeStart)
    let numberOfLayers = 100

    for index in 0..<numberOfLayers {
      let layer = CAShapeLayer()
      layer.path = combinedPath
      layer.fillColor = NSColor.clear.cgColor
      layer.lineWidth = strokeWidth
      layer.lineCap = .butt  // Use butt caps to prevent overlapping at segment boundaries
      layer.lineJoin = .round
      layer.strokeColor = NSColor.white.cgColor

      // Opacity decreases from tail to head
      // Layer 0 (at the tail/start) has lowest opacity
      // Layer 9 (at the head/end) has highest opacity (100%)
      layer.opacity = Float(Double(index + 1) / Double(numberOfLayers))

      view.layer?.addSublayer(layer)

      // Animate this layer's visible stroke segment
      let animGroup = CAAnimationGroup()
      animGroup.duration = animationDuration
      animGroup.repeatCount = .infinity
      animGroup.timingFunction = CAMediaTimingFunction(name: .linear)

      // Each layer shows a NON-OVERLAPPING segment of equal length (drawingWindowLength / numberOfLayers)
      // Layer 0: shows segment 0 (tail, lowest opacity)
      // Layer 1: shows segment 1 (next segment)
      // Layer 9: shows segment 9 (head, highest opacity)
      let layerLength = drawingWindowLength / Double(numberOfLayers)
      let startOffset = layerLength * Double(index)

      // strokeStart: each layer starts at a different position
      // Animates from its offset position to 0.5 + offset for seamless looping
      let startAnim = CABasicAnimation(keyPath: "strokeStart")
      startAnim.fromValue = startOffset / 2
      startAnim.toValue = 0.5 + startOffset / 2

      // strokeEnd: positioned layerLength ahead of strokeStart
      // Each segment is adjacent but non-overlapping
      let endAnim = CABasicAnimation(keyPath: "strokeEnd")
      endAnim.fromValue = (startOffset + layerLength) / 2
      endAnim.toValue = 0.5 + (startOffset + layerLength) / 2

      animGroup.animations = [startAnim, endAnim]
      layer.add(animGroup, forKey: "animation_\(index)")
    }

    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    // Nothing to update
  }

  private func parseCMDLogoSVG(from url: URL, targetSize: CGFloat) -> CGPath? {
    guard let svgString = try? String(contentsOf: url, encoding: .utf8) else {
      return nil
    }

    // Calculate scaling factor to transform from SVG's 16x16 viewport to target size
    let scale = targetSize / 16.0
    let combinedPath = CGMutablePath()

    // Extract line elements from SVG using regex
    // Matches: <line x1="3" y1="2.5" x2="6" y2="2.5" ... />
    // The SVG contains 12 line elements ordered to flow continuously around the logo
    let pattern = #"<line\s+x1="([\d.]+)"\s+y1="([\d.]+)"\s+x2="([\d.]+)"\s+y2="([\d.]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return nil
    }

    let matches = regex.matches(in: svgString, options: [], range: NSRange(svgString.startIndex..., in: svgString))

    // Duplicate the path by looping twice through all line segments
    // This allows the animation to loop seamlessly by animating through 0→0.5 instead of 0→1
    // When the animation reaches position 0.5, it's actually at the start of the second copy
    // which looks identical to the beginning, creating a seamless loop
    for _ in 0..<2 {
      for match in matches {
        // Extract x1, y1, x2, y2 coordinates from the regex match
        guard match.numberOfRanges == 5,
              let x1Range = Range(match.range(at: 1), in: svgString),
              let y1Range = Range(match.range(at: 2), in: svgString),
              let x2Range = Range(match.range(at: 3), in: svgString),
              let y2Range = Range(match.range(at: 4), in: svgString),
              let x1Value = Double(svgString[x1Range]),
              let y1Value = Double(svgString[y1Range]),
              let x2Value = Double(svgString[x2Range]),
              let y2Value = Double(svgString[y2Range]) else {
          continue
        }

        // Scale coordinates from SVG viewport to target size and add line segment
        let startPoint = CGPoint(x: CGFloat(x1Value) * scale, y: CGFloat(y1Value) * scale)
        let endPoint = CGPoint(x: CGFloat(x2Value) * scale, y: CGFloat(y2Value) * scale)

        combinedPath.move(to: startPoint)
        combinedPath.addLine(to: endPoint)
      }
    }

    return combinedPath
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    CMDLogoDrawingAnimation(size: 32)
    CMDLogoDrawingAnimation(size: 48)
    CMDLogoDrawingAnimation(size: 64)
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.black)
}
