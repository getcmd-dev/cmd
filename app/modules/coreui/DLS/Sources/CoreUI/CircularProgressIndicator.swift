// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CircularProgressIndicator

/// A circular progress indicator that shows a proportionally filled circle with a percentage in the middle.
public struct CircularProgressIndicator: View {

  public init(progress: Double, size: CGFloat = 20) {
    self.progress = max(0, min(1, progress))
    self.size = size
  }

  public var body: some View {
    ZStack {
      // Background circle
      Circle()
        .stroke(
          Color.secondary.opacity(0.2),
          lineWidth: lineWidth)

      // Progress circle
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          progressColor,
          style: StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round))
        .rotationEffect(.degrees(-90))

      // Percentage label in the center
      Text(percentageLabel)
        .font(.system(size: labelFontSize, weight: .medium))
        .foregroundColor(.primary)
    }
    .frame(width: size, height: size)
  }

  private let progress: Double
  private let size: CGFloat

  private var percentageLabel: String {
    "\(Int(round(progress * 100)))"
  }

  private var lineWidth: CGFloat {
    size * 0.12
  }

  private var labelFontSize: CGFloat {
    size * 0.30
  }

  private var progressColor: Color {
    if progress < 0.6 {
      .green
    } else if progress < 0.8 {
      .yellow
    } else {
      .red
    }
  }
}

// MARK: - Preview

#Preview("Basic Usage") {
  VStack(spacing: 20) {
    CircularProgressIndicator(progress: 0.25)
    CircularProgressIndicator(progress: 0.5)
    CircularProgressIndicator(progress: 0.75)
    CircularProgressIndicator(progress: 0.9)
  }
  .padding()
}

#Preview("Different Sizes") {
  HStack(spacing: 20) {
    CircularProgressIndicator(progress: 0.6, size: 16)
    CircularProgressIndicator(progress: 0.6, size: 20)
    CircularProgressIndicator(progress: 0.6, size: 24)
  }
  .padding()
}

#Preview("Token Usage Example") {
  HStack(spacing: 20) {
    CircularProgressIndicator(progress: 0.3)
    CircularProgressIndicator(progress: 0.65)
    CircularProgressIndicator(progress: 0.85)
  }
  .padding()
}
