// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import Foundation
import Observation
import SwiftUI
import ToolFoundation
import ToolTypesFoundation
import ToolUI

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: ACPTool.Use.Status, input: ACPTool.Use.Input, projectRoot: URL?) {
    self.status = status.value
    self.input = input
    self.projectRoot = projectRoot
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
  }

  let input: ACPTool.Use.Input
  let projectRoot: URL?
  var status: ToolUseExecutionStatus<ACPTool.Use.Input, ACPTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(_, let result) = status else { return nil }
    switch result {
    case .success(let output):
      var representation = "⏺ \(input.title)\n"

      // Add content representation based on output content
      for content in output.content {
        switch content {
        case .aCPToolOutputMediaContent(let mediaContent):
          switch mediaContent.content {
          case .aCPToolOutputMediaContentText(let textContent):
            representation += "  ⎿ \(textContent.text.prefix(100))\n"
          case .aCPToolOutputMediaContentImage(let imageContent):
            representation += "  ⎿ [Image: \(imageContent.mimeType)]\n"
          case .aCPToolOutputMediaContentAudio(let audioContent):
            representation += "  ⎿ [Audio: \(audioContent.mimeType)]\n"
          case .aCPToolOutputMediaContentResourceLink(let resourceLink):
            representation += "  ⎿ [Resource: \(resourceLink.name)]\n"
          case .aCPToolOutputMediaContentResource(let resource):
            switch resource.resource {
            case .aCPToolOutputMediaContentResourceEmbeddedResourceText(let textResource):
              representation += "  ⎿ [Embedded Resource: \(textResource.uri)]\n"
            case .aCPToolOutputMediaContentResourceEmbeddedResourceBlob(let blobResource):
              representation += "  ⎿ [Embedded Resource: \(blobResource.uri)]\n"
            }
          }

        case .aCPToolOutputDiff(let diff):
          representation += "  ⎿ [Diff: \(diff.path)]\n"

        case .aCPToolOutputTerminal(let terminal):
          representation += "  ⎿ [Terminal: \(terminal.terminalId)]\n"
        }
      }

      return representation + "\n"

    case .failure(let error):
      return """
        ⏺ \(input.title)
          ⎿ Failed: \(error.toolUseErrorDescription)


        """
    }
  }
}
