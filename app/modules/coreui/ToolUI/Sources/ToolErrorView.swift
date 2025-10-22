// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import JSONFoundation
import Markdown
import SwiftUI
import ToolFoundation
import ToolTypesFoundation

// MARK: - ToolErrorView

public struct ToolErrorView: View {
  public init(_ error: Error) {
    self.error = error
  }

  public var body: some View {
    Text(colorScheme.markDownStyle.markdown(for: error.toolUseErrorDescription))
      .textSelection(.enabled)
      .foregroundColor(colorScheme.redError)
  }

  @Environment(\.colorScheme) private var colorScheme

  private let error: Error
}

extension Error {
  public var toolUseErrorDescription: String {
    if let toolError = self as? ToolError {
      if let content = try? (self as? ToolError)?.value.decode(as: [ToolsSchema.ACPToolOutput_Content].self) {
        let textContent = content.compactMap { content in
          switch content {
          case .aCPToolOutputMediaContent(let mediaContent):
            switch mediaContent.content {
            case .aCPToolOutputMediaContentText(let text):
              text.text
            default:
              nil
            }

          default:
            nil
          }
        }
        if !textContent.isEmpty {
          return textContent.joined(separator: "\n")
        } else {
          return localizedDescription
        }
      } else {
        if case .string(let text) = toolError.value {
          return text
        } else {
          return localizedDescription
        }
      }
    } else {
      return localizedDescription
    }
  }
}
