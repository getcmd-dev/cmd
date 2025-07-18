// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import DLS
import FileDiffFoundation
import LoggingServiceInterface
import SwiftUI

// MARK: - DiffView

/// Displays code differences with highlighting.
/// Its content will take the width necessary to display the longest line. If that's too wide for the container, it should be wrapped in a scroll view.
public struct DiffView: View {

  public init(change: FileDiffViewModel) {
    self.change = change
  }

  public var body: some View {
    content
      .background(colorScheme.xcodeEditorBackground)
  }

  let change: FileDiffViewModel

  private enum Constants {
    static let maxUnchangedLinesContent = 3
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var desiredTextWidth: CGFloat = 0

  private var changedLines: [FormattedLineChange] {
    change.formattedDiff?.changes ?? []
  }

  private var partialDiffRanges: [Range<Int>] {
    changedLines.changedSection(minSeparation: Constants.maxUnchangedLinesContent)
  }

  @ViewBuilder
  private var content: some View {
    // Get the desired width for the rendered text.
    VStack(alignment: .leading) {
      ForEach(partialDiffRanges, id: \.id) { range in
        PartialDiffView(change: change, partialRange: range)
      }
    }
    .readSize { newValue in
      desiredTextWidth = newValue.width
    }

    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(zip(partialDiffRanges.indices, partialDiffRanges)), id: \.1.id) { idx, range in
        if idx != 0 {
          // Add hidden lines indicator
          HStack {
            Rectangle()
              .frame(width: 10, height: 1)
              .foregroundColor(.gray.opacity(0.7))
            Text(hiddenLineText(idx: idx))
              .font(.caption2)
              .foregroundColor(.gray.opacity(0.7))
            Rectangle()
              .frame(height: 1)
              .foregroundColor(.gray.opacity(0.7))
          }.frame(width: nil, height: 15)
        }
        PartialDiffView(change: change, partialRange: range)
      }
    }
    .frame(minWidth: desiredTextWidth)
    .padding(.vertical, 5)
  }

  private func hiddenLineText(idx: Int) -> String {
    let n = partialDiffRanges[idx].lowerBound - partialDiffRanges[idx - 1].upperBound
    return "\(n) hidden line\(n == 1 ? "" : "s")"
  }

}

// MARK: - PartialDiffView

/// A partial diff displays a continous range of code that contains the modifications.
/// The modification themselved might not be continuous, as we allow for a limited spacing
/// beween changes before splitting the diff for clarity.
struct PartialDiffView: View {

  init(change: FileDiffViewModel, partialRange: Range<Int>) {
    self.change = change
    self.partialRange = partialRange
    continousChanges = change.formattedDiff?.changes.continousChanges(in: partialRange) ?? []
  }

  var body: some View {
    HoverReader { hoveringPosition in
      ZStack(alignment: .topLeading) {
        background
        Text(content)
          .font(Font.custom("Menlo", fixedSize: Constants.fontSize))
          .fixedSize()
          .textSelection(.enabled)
          .padding(.horizontal, 5)
          .readingSize { newValue in
            if changedLines.count > 0 {
              lineHeight = newValue.height / CGFloat(changedLines.count > 0 ? partialRange.count : 1)
            }
          }
        partialApply(hoveringPosition: hoveringPosition)
      }
    }
  }

  private enum Constants {
    static let fontSize: CGFloat = 11
  }

  @State private var lineHeight: CGFloat = 0
  @Environment(\.colorScheme) private var colorScheme

  @Bindable private var change: FileDiffViewModel

  private let partialRange: Range<Int>
  private let continousChanges: [Range<Int>]

  private var changedLines: [FormattedLineChange] { change.formattedDiff?.changes ?? [] }

  /// A colored background for the diff view.
  @ViewBuilder
  private var background: some View {
    VStack(spacing: 0) {
      ForEach(partialRange, id: \.self) { i in
        switch changedLines[i].change.type {
        default:
          Rectangle()
            .fill(backgroundColor(for: changedLines[i]))
            .frame(height: lineHeight)
        }
      }
    }
  }

  private var content: AttributedString {
    var result = AttributedString()
    for i in partialRange {
      guard let line = changedLines[safe: i]?.formattedContent else {
        defaultLogger.error("inconsistent diff data")
        continue
      }
      if i == partialRange.upperBound - 1, line.characters.last == "\n" {
        // Remove the last newline character
        let truncatedLine = line[line.startIndex..<line.index(line.endIndex, offsetByCharacters: -1)]
        result.append(AttributedString(truncatedLine))
      } else {
        result.append(line)
      }
    }
    return result
  }

  /// A zone that will show an option to do a partial apply when hovered
  @ViewBuilder
  private func partialApply(hoveringPosition: ObservableValue<CGPoint?>) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(zip(continousChanges.indices, continousChanges)), id: \.1.id) { idx, range in
        VStack(spacing: 0) {
          Spacer()
            .frame(height: topSpacing(forContinousRangeIdx: idx))
          PartialApplyView(
            hoveringPosition: hoveringPosition,
            apply: {
              Task {
                try await change.handleApply(changes: Array(changedLines[range]))
              }
            },
            reject: {
              Task {
                try change.handleReject(changes: Array(changedLines[range]))
              }
            })
            .frame(height: lineHeight * CGFloat(range.count))
        }
      }
    }
  }

  private func topSpacing(forContinousRangeIdx idx: Int) -> CGFloat {
    let lineCount = idx > 0
      ? continousChanges[idx].lowerBound - continousChanges[idx - 1].upperBound
      : continousChanges[idx].lowerBound - partialRange.lowerBound
    return lineHeight * CGFloat(lineCount)
  }

  /// Which color to use for the background of a given line.
  private func backgroundColor(for line: FormattedLineChange) -> Color {
    switch line.change.type {
    case .added:
      colorScheme.addedLineDiffBackground
    case .removed:
      colorScheme.removedLineDiffBackground
    default:
      Color.clear
    }
  }

}

// MARK: - PartialApplyView

struct PartialApplyView: View {

  @Bindable var hoveringPosition: ObservableValue<CGPoint?>

  let apply: () -> Void
  let reject: () -> Void

  var body: some View {
    GeometryReader { proxy in
      Rectangle()
        .foregroundColor(Color.clear)
        .onChange(of: hoveringPosition.value) { _, newVal in
          if let newVal {
            isHovered = proxy.frame(in: .global).with(bottomPadding: 10 + Constants.buttonHeight).contains(newVal)
          } else {
            isHovered = false
          }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
//    .overlay(alignment: .bottomTrailing) {
//      applyButtons
//        .alignmentGuide(.bottom) { $0[.top] }
//    }
  }

  private enum Constants {
    static let buttonHeight: CGFloat = 20
  }

  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

//  @ViewBuilder
//  private var applyButtons: some View {
//    if isHovered {
//      HStack(spacing: 0) {
//        Button(action: {
//          apply()
//        }) {
//          Text("Apply")
//            .font(.system(size: 11, weight: .medium))
//            .foregroundColor(.white)
//            .padding(.horizontal, 12)
//            .frame(maxHeight: .infinity)
//            .background(colorScheme.addedLineDiffBackground)
//        }
//        .buttonStyle(.plain)
//
//        Button(action: {
//          reject()
//        }) {
//          Text("Reject")
//            .font(.system(size: 11, weight: .medium))
//            .foregroundColor(.white)
//            .padding(.horizontal, 12)
//            .frame(maxHeight: .infinity)
//            .background(colorScheme.removedLineDiffBackground)
//        }
//        .buttonStyle(.plain)
//      }
//      .frame(height: Constants.buttonHeight)
//      .roundedCorner(radius: 4, corners: [.bottomLeft, .bottomRight])
//      .frame(maxWidth: .infinity, alignment: .trailing)
//      .padding(.trailing, 8)
//    }
//  }

}

extension CGRect {
  /// Extend the rect with more space at the bottom.
  fileprivate func with(bottomPadding: CGFloat) -> CGRect {
    CGRect(x: minX, y: minY, width: width, height: height + bottomPadding)
  }
}
