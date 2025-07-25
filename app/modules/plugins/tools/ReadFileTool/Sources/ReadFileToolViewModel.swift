// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import Foundation
import HighlighterServiceInterface
import Observation
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: ReadFileTool.Use.Status, input: ReadFileTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status {
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
  var status: ToolUseExecutionStatus<ReadFileTool.Use.Output>
  var highlightedContent: AttributedString?

  @ObservationIgnored
  @Dependency(\.highlighter) private var highlighter
}
