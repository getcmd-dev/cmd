// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import ServerServiceInterface
import SwiftUI
import ToolFoundation

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
    case .completed(.success(let output)):
      successView(output: output)
    case .completed(.failure(let error)):
      errorView(error: error)
    }
  }

  @State private var isExpanded = false
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var pendingApprovalView: some View {
    HStack {
      Icon(systemName: "magnifyingglass")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Waiting for approval: Search \(toolUse.input.regex)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var rejectedView: some View {
    HStack {
      Icon(systemName: "magnifyingglass")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Rejected: Search \(toolUse.input.regex)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var runningView: some View {
    HStack {
      Icon(systemName: "magnifyingglass")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Searching \(toolUse.input.regex)...")
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

  @ViewBuilder
  private func successView(output: SearchFilesTool.Use.Output) -> some View {
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
          Icon(systemName: "magnifyingglass")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }

        Text("Searched \(toolUse.input.regex)")
          .foregroundColor(foregroundColor)
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      .acceptClickThrough()
      if isExpanded {
        ForEach(output.results) { result in
          VStack(alignment: .leading) {
            HStack(spacing: 4) {
              FileIcon(filePath: result.pathURL)
                .frame(width: 14, height: 14)
              Text(result.fileName)
                .lineLimit(1)
              Text(shorten(path: result.directoryPath, in: output.rootPath))
                .font(.caption)
                .foregroundColor(colorScheme.toolUseForeground)
                .lineLimit(1)
                .truncationMode(.head)
                .layoutPriority(-1) // Lower priority means this will be truncated first
              Spacer(minLength: 0)
              Text(display(for: result))
                .font(.caption)
                .foregroundColor(colorScheme.toolUseForeground)
                .lineLimit(1)
            }
          }
        }
      }
    }.onHover { isHovered = $0 }
  }

  @ViewBuilder
  private func errorView(error: Error) -> some View {
    HStack {
      Icon(systemName: "doc.text")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Searching \(toolUse.input.regex) failed: \(error.localizedDescription)")
        .foregroundColor(foregroundColor)
    }
  }

  private func shorten(path: String, in rootPath: String) -> String {
    var path = path.replacingOccurrences(of: rootPath, with: "")
    if path.hasPrefix("/") {
      path.removeFirst()
    }
    return path
  }

  private func display(for searchResult: Schema.SearchFileResult) -> String {
    let matchedLines = searchResult.searchResults
      .filter(\.isMatch)
    guard
      let firstMatchedLine = matchedLines.first?.line,
      let lastMatchedLine = matchedLines.last?.line
    else {
      return ""
    }
    if firstMatchedLine == lastMatchedLine {
      return "L\(firstMatchedLine)"
    } else {
      return "L\(firstMatchedLine)-\(lastMatchedLine)"
    }
  }
}

// MARK: - Schema.SearchFileResult + Identifiable

extension Schema.SearchFileResult: Identifiable {
  public var id: String { path }
  public var pathURL: URL { URL(fileURLWithPath: path) }
  public var fileName: String { pathURL.lastPathComponent }
  public var directoryPath: String { pathURL.deletingLastPathComponent().path }
}

// MARK: - Schema.SearchResult + Identifiable

extension Schema.SearchResult: Identifiable {
  public var id: String { "\(line)-\(text)" }
}
