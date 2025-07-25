// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import DLS
import SwiftUI

// MARK: - CodePreview

// TODO: find more efficient way to render. The sizing / attribute string might make this slow.
// Given the fixed size of the text, we can precompute the size of the text and then render it.
// https://stackoverflow.com/questions/79529599/rendering-a-long-string-in-a-text-view-takes-forever
// Maybe falling back to a scroll view with UI kit that splits text by lines would work? What about text selection?

/// A preview of a code snippet.
/// If the content is long enough, it can be expanded to a larger size by the user.
public struct CodePreview: View {

  // TODO: look at separating this in two distinct views. One for a file change diff, and the other one for a code preview with no diff.
  public init(
    filePath: URL?,
    language: String? = nil,
    startLine: Int? = nil,
    endLine: Int? = nil,
    content: String,
    highlightedContent: AttributedString? = nil,
    collapsedHeight: CGFloat = Constants.defaultCollapsedHeight,
    expandedHeight: CGFloat? = Constants.defaultExpandedHeight)
  {
    self.filePath = filePath
    self.language = language
    self.content = content
    self.startLine = startLine
    self.endLine = endLine
    self.collapsedHeight = collapsedHeight
    self.expandedHeight = max(collapsedHeight, expandedHeight ?? .infinity)
    self.highlightedContent = highlightedContent
    fileChange = nil
  }

  public init(
    language: String? = nil,
    fileChange: FileDiffViewModel,
    collapsedHeight: CGFloat = Constants.defaultCollapsedHeight,
    expandedHeight: CGFloat? = Constants.defaultExpandedHeight)
  {
    filePath = fileChange.filePath
    self.language = language
    content = "" // Not used when fileChange is provided.
    startLine = nil
    endLine = nil
    self.collapsedHeight = collapsedHeight
    self.expandedHeight = max(collapsedHeight, expandedHeight ?? .infinity)
    highlightedContent = nil
    self.fileChange = fileChange
  }

  // MARK: Private Constants

  public enum Constants {
    public static let defaultCollapsedHeight: CGFloat = 50
    public static let defaultExpandedHeight: CGFloat = 100
    static let cornerRadius: CGFloat = 3
    static let borderWidth: CGFloat = 1
    static let defaultFontSize: CGFloat = 11
    static let expandButtonVerticalPadding: CGFloat = 4
    /// How much more content we are willing to show to avoid showing a button to expand
    static let textHeightTolerance: CGFloat = 10
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // This first hidden view is used to know the desired size of the text.
      textView
        .readSize(Binding(
          get: { CGSize(width: desiredTextWidth ?? 0, height: desiredTextHeight ?? 0) },
          set: { newValue in
            desiredTextWidth = newValue.width
            desiredTextHeight = newValue.height
          }))
      // Now render the text in a scroll view.
      ScrollView(scrollDirections, showsIndicators: true) {
        textView
          .background(colorScheme.xcodeEditorBackground)
          .frame(maxWidth: desiredTextWidth, alignment: .leading)
      }
      .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
      if showExpandButton {
        expandButton
      }
    }
    .onGeometryChange(for: CGSize.self) { proxy in
      proxy.size
    } action: { newValue in
      maxWidth = newValue.width
    }
    .padding(1)
    .background(colorScheme.xcodeEditorBackground)
  }

  let filePath: URL?
  let language: String?
  let startLine: Int?
  let endLine: Int?
  let collapsedHeight: CGFloat
  let expandedHeight: CGFloat

  @ViewBuilder
  var expandButton: some View {
    Button(action: {
      isExpanded.toggle()
    }, label: {
      HStack(spacing: 0) {
        Spacer()
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .padding(.vertical, Constants.expandButtonVerticalPadding)
        Spacer()
      }
      .background(Color.tappableClearButton)
    })
    .buttonStyle(.plain)
  }

  @ViewBuilder
  var textView: some View {
    if let fileChange {
      DiffView(change: fileChange)
    } else {
      LongText(textContent)
        // Same font as Xcode
        .font(NSFont(name: "Menlo", size: Constants.defaultFontSize))
        .fixedSize()
        .textSelection(.enabled)
        .padding(5)
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var desiredTextWidth: CGFloat?
  @State private var desiredTextHeight: CGFloat?
  @State private var maxWidth = CGFloat.infinity
  @State private var isExpanded = false

  private let content: String

  private let highlightedContent: AttributedString?
  private let fileChange: FileDiffViewModel?

  private var textContent: AttributedString {
    if let highlightedContent {
      return highlightedContent
    } else {
      if let startLine, let endLine {
        let content = content
          .split(separator: "\n", omittingEmptySubsequences: false)
          .dropFirst(startLine - 1)
          .prefix(endLine - startLine + 1)
          .joined(separator: "\n")
        return AttributedString(content).with(color: colorScheme.primaryForeground.nsColor)
      } else {
        return AttributedString(content).with(color: colorScheme.primaryForeground.nsColor)
      }
    }
  }

  private var height: CGFloat {
    let targetHeight = isExpanded ? expandedHeight : collapsedHeight
    guard let desiredTextHeight else { return targetHeight }
    if desiredTextHeight < targetHeight + Constants.textHeightTolerance {
      // We're ok using a bit more height to show all the content.
      return desiredTextHeight
    }
    return targetHeight
  }

  private var showExpandButton: Bool {
    if isExpanded { return true }
    guard let desiredTextHeight else { return false }
    guard !isExpanded else { return false }
    return desiredTextHeight > height + Constants.textHeightTolerance
  }

  private var scrollDirections: Axis.Set {
    guard let desiredTextHeight, let desiredTextWidth else { return [] }

    var directions: Axis.Set = []
    if desiredTextHeight > height {
      directions.insert(.vertical)
    }
    if desiredTextWidth > maxWidth {
      directions.insert(.horizontal)
    }
    return directions
  }
}
