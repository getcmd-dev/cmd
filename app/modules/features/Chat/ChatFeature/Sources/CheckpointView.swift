// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CheckpointServiceInterface
import DLS
import SwiftUI

// MARK: - CheckpointView

/// A view that displays a checkpoint in the chat history.
struct CheckpointView: View {

  init(checkpoint: Checkpoint, onRestoreTapped: ((Checkpoint) -> Void)? = nil) {
    self.checkpoint = checkpoint
    self.onRestoreTapped = onRestoreTapped
  }

  let checkpoint: Checkpoint
  let onRestoreTapped: ((Checkpoint) -> Void)?

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 8) {
        CircleWithLine(circleRadiusRatio: 0.25, lineWidthRatio: 0.15)
          .fill(Color.blue)
          .frame(square: 16)
          .scaledToFit()
          .frame(width: ChatView.Constants.chatPadding)

        if isHovered {
          HoveredButton(
            action: {
              onRestoreTapped?(checkpoint)
            },
            onHover: { isHovered in
              isButtonHovered = isHovered
            },
            content: {
              Text("Restore checkpoint")
                .foregroundColor(isButtonHovered ? Color.primary : Color.gray)
            })
        }
      }
      .onHover(perform: { isHovered in
        self.isHovered = isHovered
      })

      Spacer()
    }
    .frame(height: height)
  }

  @State private var isHovered = false
  @State private var isButtonHovered = false

  private var height: CGFloat {
    isHovered ? 25 : 10
  }

}

// MARK: - CircleWithLine

/// A line with a circle at the center, the icon for the checkpoint.
struct CircleWithLine: Shape {
  var circleRadiusRatio: CGFloat
  var lineWidthRatio: CGFloat

  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height

    let circleRadius = min(width, height) * circleRadiusRatio
    let lineHeight = height * lineWidthRatio
    let centerX = rect.midX
    let centerY = rect.midY

    var path = Path()

    path.addRoundedRect(in: CGRect(
      x: centerX - lineHeight / 2,
      y: rect.minY,
      width: lineHeight,
      height: height), cornerSize: CGSize(width: lineHeight / 2, height: lineHeight / 2))

    path.addEllipse(in: CGRect(
      x: centerX - circleRadius,
      y: centerY - circleRadius,
      width: 2 * circleRadius,
      height: 2 * circleRadius))

    return path
  }
}
