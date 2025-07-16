// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import CodePreview
import Dependencies
import DLS
import Down
import FileDiffTypesFoundation
import FoundationInterfaces
import LoggingServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ChatMessageView

struct ChatMessageView: View {

  // MARK: Private Constants

  enum Constants {
    static let cornerRadius: CGFloat = 5
    static let userTextHorizontalPadding: CGFloat = 8
    static let textVerticalPadding: CGFloat = 8
    static let toolPadding: CGFloat = 8
    static let checkpointPadding: CGFloat = 8
  }

  let message: ChatMessageContentWithRole

  var body: some View {
    VStack(alignment: .leading) {
      GeometryReader { geometry in
        ReshareGeometry(geometry, geometryReader: $size) {
          Color.clear
        }
      }.frame(height: 0)

      HStack {
        VStack(alignment: .leading, spacing: 0) {
          switch message.content {
          case .text(let textContent):
            if !textContent.attachments.isEmpty {
              AttachmentsView(attachments: .constant(textContent.attachments), isEditable: false)
                .padding(5)
                .padding(.top, 2)
            }
            ForEach(textContent.elements) { element in
              textElementView(element)
            }

          case .toolUse(let toolUse):
            ToolUseView(toolUse: toolUse.toolUse)
              .padding(.horizontal, horizontalPadding)
              .padding(.vertical, Constants.toolPadding)

          case .nonUserFacingText:
            EmptyView()

          case .reasoning(let reasoningContent):
            ReasoningMessageView(reasoning: reasoningContent)
              .padding(.horizontal, horizontalPadding)
              .padding(.vertical, Constants.textVerticalPadding)

          case .conversationSummary:
            EmptyView()
          }
        }
        Spacer(minLength: 0)
      }
      .background(message.role == .user ? colorScheme.secondarySystemBackground : .clear)
      .with(cornerRadius: Constants.cornerRadius)

      if let info = message.info {
        Text(info.info)
          .textSelection(.enabled)
          .font(.system(size: 11))
          .foregroundColor(infoColor(for: info.level))
      }
    }
  }

  var style: MarkdownStyle {
    MarkdownStyle(colorScheme: colorScheme)
  }

  @State private var size = CGSize.zero

  @Environment(\.colorScheme) private var colorScheme

  private var horizontalPadding: CGFloat {
    message.role == .user ? Constants.userTextHorizontalPadding : 0
  }

  private func infoColor(for level: ChatMessageContentWithRoleModel.Info.InfoLevel) -> SwiftUI.Color {
    switch level {
    case .info:
      .secondary
    case .warning:
      .orange
    case .error:
      .red
    }
  }

  @ViewBuilder
  private func textElementView(_ element: TextFormatter.Element) -> some View {
    switch element {
    case .text(let text):
      // Only format the text for the assistant messages.
      let attributedText = message.role == .user ? plainText(for: text) : markdown(for: text)
      LongText(attributedText, maxWidth: size.width - 2 * horizontalPadding)
        .textSelection(.enabled)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Constants.textVerticalPadding)
        .cornerRadius(8)

    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: message.role)
    }
  }

  private func markdown(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let markDown = Down(markdownString: text.text)
    do {
      let attributedString = try markDown.toAttributedString(using: style)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      defaultLogger.error("Error parsing markdown", error)

      return AttributedString(text.text)
    }
  }

  private func plainText(for text: TextFormatter.Element.TextElement) -> AttributedString {
    AttributedString(text.text).settingAttributes(.init([
      .foregroundColor: style.baseFontColor,
      .font: style.baseFont,
      .paragraphStyle: style.baseParagraphStyle,
    ]))
  }
}

// MARK: - ToolUseView

struct ToolUseView: View {
  let toolUse: any ToolUse

  var body: some View {
    VStack {
      HStack(spacing: 0) {
        if let display = (toolUse as? (any DisplayableToolUse))?.body {
          AnyView(display)
        } else {
          HStack(spacing: 0) {
            Image(systemName: "hammer")
              .foregroundColor(colorScheme.toolUseForeground)
            Text(" Tool used: \(toolUse.toolName)")
              .foregroundColor(colorScheme.toolUseForeground)
              .font(.system(size: 11))
              .font(.body)
          }
          .padding(3)
        }
        #if DEBUG
        Spacer()
        IconButton(
          action: {
            if let debugInput {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(debugInput, forType: .string)
            }
          },
          systemName: "doc.on.doc",
          cornerRadius: 0,
          withCheckMark: true)
          .frame(width: 10, height: 10)
          .font(.system(size: 10))
          .foregroundColor(.orange)
        #endif
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  #if DEBUG
  private var debugInput: String? {
    if
      let data = try? JSONEncoder().encode(toolUse.input),
      let string = String(data: data, encoding: .utf8)
    {
      return string
    }
    return nil
  }
  #endif
}

// MARK: - CodeBlockContentView

// TODO: Remove code change edit from this view, since they are now handled by the edit tool.
struct CodeBlockContentView: View {

  // MARK: Internal

  @Bindable var code: TextFormatter.Element.CodeBlockElement
  let role: MessageRole

  let iconSizes: CGFloat = 15

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        if let filePath {
          FileIcon(filePath: filePath)
            .frame(width: 12, height: 12)
          Text(filePath.lastPathComponent)
        }
        Spacer()
        #if DEBUG
        IconButton(
          action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code.rawContent, forType: .string)
          },
          systemName: "doc.on.doc",
          cornerRadius: 0,
          withCheckMark: true)
          .frame(width: iconSizes, height: iconSizes)
          .foregroundColor(.orange)
        #endif
        if let copyableContent = code.copyableContent {
          IconButton(
            action: {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(copyableContent, forType: .string)
            },
            systemName: "doc.on.doc",
            cornerRadius: 0,
            withCheckMark: true)
            .frame(width: iconSizes, height: iconSizes)
        }
        if code.isComplete {
          if code.fileChange != nil {
//            IconButton(
//              action: {
//                reapplyFileChange()
//              },
//              systemName: "arrow.trianglehead.clockwise",
//              withCheckMark: true)
//              .frame(width: iconSizes, height: iconSizes)
            if isApplyingChange {
              ProgressView()
                .controlSize(.small)
                .frame(width: iconSizes, height: iconSizes)
            } else if hasAppliedChanges == true {
              Image(systemName: "checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: iconSizes, height: iconSizes)
            } else {
              IconButton(
                action: {
                  applyFileChange()
                },
                systemName: "play",
                withCheckMark: true)
                .frame(width: iconSizes, height: iconSizes)
            }
          }
        } else {
          ProgressView()
            .controlSize(.small)
            .frame(width: iconSizes, height: iconSizes)
        }
      }
      .padding(7)
      .overlay(
        Rectangle()
          .frame(height: 0.5)
          .foregroundColor(colorScheme.textAreaBorderColor),
        alignment: .bottom)

      if hasAppliedChanges != true {
        if let fileChange = code.fileChange {
          CodePreview(
            language: code.language,
            fileChange: fileChange,
            collapsedHeight: 500,
            expandedHeight: nil)
        } else {
          CodePreview(
            filePath: code.filePath.map { URL(fileURLWithPath: $0) },
            language: code.language,
            startLine: nil,
            endLine: nil,
            content: code.content,
            highlightedContent: code.highlightedText,
            collapsedHeight: 500,
            expandedHeight: nil)
        }
      }
    }
    .padding(.bottom, 2)
    .with(
      cornerRadius: Constants.codePreviewCornerRadius,
      backgroundColor: colorScheme.primaryBackground,
      borderColor: colorScheme.textAreaBorderColor)
    .foregroundColor(role == .user ? .white : .primary)
  }

  @Dependency(\.fileManager) private var fileManager: FileManagerI
  @State private var isApplyingChange = false

  private var hasAppliedChanges: Bool? {
    code.fileChange?.formattedDiff?.changes.filter { $0.change.type != .unchanged }.isEmpty
  }

  private func applyFileChange() {
    isApplyingChange = true
    Task {
      do {
        try await code.fileChange?.handleApplyAllChange()
        isApplyingChange = false
      } catch {
        defaultLogger.error("Error applying code change: \(error)")
        isApplyingChange = false
      }
    }
  }

//  private func reapplyFileChange() {
//    Task {
//      code.fileChange?.handleReapplyChange()
//    }
//  }

  // MARK: Private

  private enum Constants {
    static let codePreviewCornerRadius: CGFloat = 3
    static let codePreviewBorderWidth: CGFloat = 1
  }

  @Environment(\.colorScheme) private var colorScheme

  private var filePath: URL? {
    code.filePath.map { URL(fileURLWithPath: $0) }
  }

}

extension NSAttributedString {

  /// Trims new lines and whitespaces off the beginning and the end of attributed strings
  public func trimmedAttributedString() -> NSAttributedString {
    let nonWhiteSpace = CharacterSet.whitespacesAndNewlines.inverted
    let startRange = string.rangeOfCharacter(from: nonWhiteSpace)
    let endRange = string.rangeOfCharacter(from: nonWhiteSpace, options: .backwards)

    // If no non-whitespace characters found, return original string (it's either empty or all whitespace)
    guard let startLocation = startRange?.lowerBound, let endLocation = endRange?.lowerBound else {
      return NSAttributedString(string: "")
    }

    // Check if there's nothing to trim (already trimmed)
    if startLocation == string.startIndex, endLocation == string.index(before: string.endIndex) {
      return self
    }

    let trimmedRange = startLocation...endLocation
    return attributedSubstring(from: NSRange(trimmedRange, in: string))
  }
}

/// This is a hack to read the width of the view...
/// Wrapping the entire message view in a GeometryReader was preventing the view from being interactive.
/// So instead we use a hidden GeometryReader to get the size of the message view and reshare it with the main view through a binding.
struct ReshareGeometry<Content: View>: View {
  let content: Content

  init(_ geometry: GeometryProxy, geometryReader: Binding<CGSize>, @ViewBuilder content: () -> Content) {
    self.content = content()
    DispatchQueue.main.async {
      geometryReader.wrappedValue = geometry.size
    }
  }

  var body: some View {
    content
  }
}
