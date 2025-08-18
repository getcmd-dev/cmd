// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import Foundation
import HighlighterServiceInterface
import Observation
import SwiftUI
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: ReadFileTool.Use.Status, input: ReadFileTool.Use.Input, projectRoot: URL?) {
    self.status = status.value
    self.input = input
    displayFilePath = projectRoot.map { URL(filePath: input.path).pathRelative(to: $0) } ?? input.path
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
        if case .completed(.success(let output)) = status {
          Task {
            guard let self else { return }
            let highlightedContent = try await self.highlighter.attributedText(
              output.content,
              language: FileIcon.language(for: URL(fileURLWithPath: output.uri)),
              colors: .codeHighlight)
            self.highlightedContent = highlightedContent
          }
        }
      }
    }
  }

  let input: ReadFileTool.Use.Input
  let displayFilePath: String
  var status: ToolUseExecutionStatus<ReadFileTool.Use.Output>
  var highlightedContent: AttributedString?

  @ObservationIgnored
  @Dependency(\.highlighter) private var highlighter
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ Read(\(displayFilePath))
          ⎿ Read \(output.content.split(separator: "\n", omittingEmptySubsequences: false).count) lines


        """

    case .failure(let error):
      return """
          ⏺ Read(\(displayFilePath))
            ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
