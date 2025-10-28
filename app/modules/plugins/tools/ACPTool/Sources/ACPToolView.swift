// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import Dependencies
import DLS
import FileDiffFoundation
import LoggingServiceInterface
import Markdown
import SwiftUI
import ToolFoundation
import ToolTypesFoundation
import ToolUI
import XcodeControllerServiceInterface

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

  var body: some View {
    switch toolUse.status {
    case .notStarted:
      EmptyView()
    case .pendingApproval:
      pendingApprovalView
    case .approvalRejected:
      rejectedView
    case .running(let input):
      contentView(content: toolUse.input.content)
    case .completed(.success(let output)):
      contentView(content: output.content)
    case .completed(.failure(let error)):
      failureView(error: error)
    }
  }

  private enum Constants {
    static let hstackSpacing: CGFloat = 4
  }

  @State private var isExpanded: Bool?
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var pendingApprovalView: some View {
    VStack(alignment: .leading) {
      contentView(content: toolUse.input.content, isExpandedByDefault: true)

      ThreeDotsLoadingAnimation(baseText: "Waiting for approval")
    }
  }

  @ViewBuilder
  private var rejectedView: some View {
    HStack {
      Icon(systemName: toolIconName)
        .forTool(with: foregroundColor)
      Text("Rejected: \(title)")
        .foregroundColor(foregroundColor)
    }
  }

  private var foregroundColor: Color {
    if isHovered {
      .primary
    } else {
      colorScheme.toolUseForeground
    }
  }

  private var toolIconName: String {
    switch toolUse.input.kind {
    case .read:
      "doc.text"
    case .edit:
      "pencil"
    case .delete:
      "trash"
    case .move:
      "arrow.right.square"
    case .search:
      "magnifyingglass"
    case .execute:
      "terminal"
    case .think:
      "brain"
    case .fetch:
      "arrow.down.circle"
    case .switchMode:
      "switch.2"
    case .other:
      "questionmark.circle"
    }
  }

  private var title: String {
    guard let projectRoot = toolUse.projectRoot else {
      return toolUse.input.title
    }
    return toolUse.input.title.replacingOccurrences(of: projectRoot.path, with: ".")
  }

  @ViewBuilder
  private func contentView(content: [ToolsSchema.ACPTool_Content]?, isExpandedByDefault: Bool = false) -> some View {
    if let content {
      VStack(alignment: .leading) {
        HStack(spacing: Constants.hstackSpacing) {
          if isExpanded ?? isExpandedByDefault {
            Icon(systemName: "chevron.down")
              .forTool(with: foregroundColor)
          } else if isHovered {
            Icon(systemName: "chevron.right")
              .forTool(with: foregroundColor)
          } else {
            Icon(systemName: toolIconName)
              .forTool(with: foregroundColor)
          }

          Text(title)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundColor(foregroundColor)
        }
        .tappableTransparentBackground()
        .onTapGesture { isExpanded = !(isExpanded ?? isExpandedByDefault) }
        .acceptClickThrough()
        if isExpanded ?? isExpandedByDefault {
          contentView(for: content)
        }
      }.onHover { isHovered = $0 }
    } else {
      HStack(spacing: Constants.hstackSpacing) {
        Icon(systemName: toolIconName)
          .forTool(with: foregroundColor)
        Text("\(title)...")
          .lineLimit(1)
          .truncationMode(.middle)
          .foregroundColor(foregroundColor)
      }
    }
  }

  @ViewBuilder
  private func failureView(error: Error) -> some View {
    VStack(alignment: .leading) {
      contentView(content: toolUse.input.content)
      ToolErrorView(error)
    }
  }

  @ViewBuilder
  private func contentView(for content: [ToolsSchema.ACPTool_Content]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(content.enumerated()), id: \.offset) { _, content in
        contentItemView(for: content)
      }
    }
  }

  @ViewBuilder
  private func contentItemView(for content: ToolsSchema.ACPTool_Content) -> some View {
    switch content {
    case .aCPToolMediaContent(let mediaContent):
      mediaContentView(for: mediaContent.content)
    case .aCPToolDiffContent(let diff):
      DiffContentView(diff: diff)
    case .aCPToolTerminalContent(let terminal):
      terminalView(for: terminal)
    }
  }

  @ViewBuilder
  private func mediaContentView(for content: ToolsSchema.ACPTool_AnyMediaContent) -> some View {
    switch content {
    case .aCPToolMediaContentText(let textContent):
      Text(colorScheme.markDownStyle.markdown(for: textContent.text))
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .foregroundColor(.secondary)

    case .aCPToolMediaContentImage(let imageContent):
      if
        let data = Data(base64Encoded: imageContent.data),
        let nsImage = NSImage(data: data)
      {
        Image(nsImage: nsImage)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 400)
      } else {
        Text("[Image: \(imageContent.mimeType)]")
          .foregroundColor(.secondary)
      }

    case .aCPToolMediaContentAudio(let audioContent):
      Text("[Audio: \(audioContent.mimeType)]")
        .foregroundColor(.secondary)

    case .aCPToolMediaContentResourceLink(let resourceLink):
      VStack(alignment: .leading, spacing: 4) {
        Text(resourceLink.name)
          .font(.headline)
        if let description = resourceLink.description {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Text(resourceLink.uri)
          .font(.caption)
          .foregroundColor(.blue)
      }

    case .aCPToolMediaContentResource(let resource):
      resourceContentView(for: resource.resource)
    }
  }

  @ViewBuilder
  private func resourceContentView(for resource: ToolsSchema.ACPTool_MediaContent_Resource_EmbeddedResource) -> some View {
    switch resource {
    case .aCPToolMediaContentResourceEmbeddedResourceText(let textResource):
      VStack(alignment: .leading, spacing: 4) {
        Text("Resource: \(textResource.uri)")
          .font(.caption)
          .foregroundColor(.secondary)
        Text(textResource.text)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
      }

    case .aCPToolMediaContentResourceEmbeddedResourceBlob(let blobResource):
      Text("[Binary Resource: \(blobResource.uri)]")
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private func terminalView(for terminal: ToolsSchema.ACPTool_TerminalContent) -> some View {
    HStack(spacing: Constants.hstackSpacing) {
      Icon(systemName: "terminal")
        .forTool(with: foregroundColor)
      Text("Terminal: \(terminal.terminalId)")
        .font(.system(.body, design: .monospaced))
    }
    .foregroundColor(.secondary)
  }

}

// MARK: - DiffContentView

struct DiffContentView: View {
  init(diff: ToolsSchema.ACPTool_DiffContent) {
    self.diff = diff
    _viewModel = .init(initialValue: Self.createFileDiffViewModel(from: diff))
  }

  let diff: ToolsSchema.ACPTool_DiffContent

  var body: some View {
    FileChangeExpandablePill(
      change: viewModel,
      editState: .applied,
      startsExpanded: true,
      handleApply: { },
      handleReject: { },
      handleCopy: { },
      handleOpenFile: { file in
        do {
          try await xcodeController.open(file: file, line: nil, column: nil)
        } catch {
          defaultLogger.error("Failed to open file", error)
        }
      })
  }

  @State private var viewModel: FileDiffViewModel

  @Dependency(\.xcodeController) private var xcodeController

  private static func createFileDiffViewModel(from diff: ToolsSchema.ACPTool_DiffContent) -> FileDiffViewModel {
    let viewModel = FileDiffViewModel(
      filePath: URL(fileURLWithPath: diff.path),
      baseLineContent: diff.oldText ?? "",
      targetContent: diff.newText,
      canBeApplied: false,
      formattedDiff: nil)
    // Trigger diff computation
    viewModel.handle(newChanges: [
      .init(search: diff.oldText ?? "", replace: diff.newText),
    ])
    return viewModel
  }

}

extension Icon {
  fileprivate func forTool(with foregroundColor: Color) -> some View {
    frame(width: 14, height: 14)
      .foregroundColor(foregroundColor)
      .frame(width: 15)
  }
}
