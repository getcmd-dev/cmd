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
    toolUseErrorDescription = error.toolUseErrorDescription
  }

  public var body: some View {
    if error is CancellationError {
      Text("Cancelled")
        .foregroundColor(.secondary)
    } else {
      if toolUseErrorDescription.count > 300 {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Button(action: {
              isExpanded.toggle()
            }) {
              Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            Text("Tool failed")
              .foregroundColor(colorScheme.redError)
          }

          if isExpanded {
            Text(toolUseErrorDescription.asPlainText(colorScheme: colorScheme))
              .textSelection(.enabled)
              .foregroundColor(.primary)
          }
        }
      } else {
        Text(toolUseErrorDescription.asPlainText(colorScheme: colorScheme))
          .textSelection(.enabled)
          .foregroundColor(colorScheme.redError)
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme
  @State private var isExpanded = false

  private let toolUseErrorDescription: String

  private let error: Error
}

extension String {
  func asPlainText(colorScheme: ColorScheme) -> String {
    let attrString = colorScheme.markDownStyle.markdown(for: self)
    return NSAttributedString(attrString).string
  }
}

extension Error {
  public var toolUseErrorDescription: String {
    if let toolError = self as? ToolError {
      if let content = try? (self as? ToolError)?.value.decode(as: [ToolsSchema.ACPTool_Content].self) {
        let textContent = content.compactMap { content in
          switch content {
          case .aCPToolMediaContent(let mediaContent):
            switch mediaContent.content {
            case .aCPToolMediaContentText(let text):
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
