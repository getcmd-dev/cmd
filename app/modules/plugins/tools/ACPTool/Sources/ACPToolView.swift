// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
// import Down
import Markdown
import SwiftUI
import ToolFoundation
import ToolTypesFoundation
import ToolUI

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
    case .running:
      runningView
    case .completed(_, .success(let output)):
      successView(output: output)
    case .completed(_, .failure(let error)):
      ToolErrorView(error)
    case .failedToDecode(let error):
      ToolErrorView(error)
    }
  }

  @State private var isExpanded = false
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var pendingApprovalView: some View {
    HStack {
      Icon(systemName: toolIconName)
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Waiting for approval: \(title)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var rejectedView: some View {
    HStack {
      Icon(systemName: toolIconName)
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Rejected: \(title)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var runningView: some View {
    HStack {
      Icon(systemName: toolIconName)
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("\(title)...")
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
  private func successView(output: ACPTool.Use.Output) -> some View {
    VStack(alignment: .leading) {
      HStack {
        if isExpanded {
          Icon(systemName: "chevron.down")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else if isHovered {
          Icon(systemName: "chevron.right")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else {
          Icon(systemName: toolIconName)
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }

        Text(title)
          .foregroundColor(foregroundColor)
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      .acceptClickThrough()
      if isExpanded {
        contentView(for: output)
      }
    }.onHover { isHovered = $0 }
  }

  @ViewBuilder
  private func contentView(for output: ACPTool.Use.Output) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(output.content.enumerated()), id: \.offset) { _, content in
        contentItemView(for: content)
      }
    }
    .padding(.leading, 20)
  }

  @ViewBuilder
  private func contentItemView(for content: ToolsSchema.ACPToolOutput_Content) -> some View {
    switch content {
    case .aCPToolOutputMediaContent(let mediaContent):
      mediaContentView(for: mediaContent.content)
    case .aCPToolOutputDiff(let diff):
      diffView(for: diff)
    case .aCPToolOutputTerminal(let terminal):
      terminalView(for: terminal)
    }
  }

  @ViewBuilder
  private func mediaContentView(for content: ToolsSchema.ACPToolOutput_AnyMediaContent) -> some View {
    switch content {
    case .aCPToolOutputMediaContentText(let textContent):
      Text(colorScheme.markDownStyle.markdown(for: textContent.text))
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .foregroundColor(.secondary)

    case .aCPToolOutputMediaContentImage(let imageContent):
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

    case .aCPToolOutputMediaContentAudio(let audioContent):
      Text("[Audio: \(audioContent.mimeType)]")
        .foregroundColor(.secondary)

    case .aCPToolOutputMediaContentResourceLink(let resourceLink):
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

    case .aCPToolOutputMediaContentResource(let resource):
      resourceContentView(for: resource.resource)
    }
  }

  @ViewBuilder
  private func resourceContentView(for resource: ToolsSchema.ACPToolOutput_MediaContent_Resource_EmbeddedResource) -> some View {
    switch resource {
    case .aCPToolOutputMediaContentResourceEmbeddedResourceText(let textResource):
      VStack(alignment: .leading, spacing: 4) {
        Text("Resource: \(textResource.uri)")
          .font(.caption)
          .foregroundColor(.secondary)
        Text(textResource.text)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
      }

    case .aCPToolOutputMediaContentResourceEmbeddedResourceBlob(let blobResource):
      Text("[Binary Resource: \(blobResource.uri)]")
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private func diffView(for diff: ToolsSchema.ACPToolOutput_Diff) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Changed: \(diff.path)")
        .font(.headline)
      if let oldText = diff.oldText {
        Text("- \(oldText)")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.red)
      }
      Text("+ \(diff.newText)")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.green)
    }
    .padding(8)
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(4)
  }

  @ViewBuilder
  private func terminalView(for terminal: ToolsSchema.ACPToolOutput_Terminal) -> some View {
    HStack {
      Icon(systemName: "terminal")
        .frame(width: 14, height: 14)
      Text("Terminal: \(terminal.terminalId)")
        .font(.system(.body, design: .monospaced))
    }
    .foregroundColor(.secondary)
  }

}
