// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import JSONFoundation
import SwiftUI
import ToolFoundation
import ToolTypesFoundation

#if DEBUG

#Preview("Tool Error - Short") {
  ToolErrorView(AppError("Something bad happened"))
    .frame(minWidth: 200, minHeight: 50)
}

#Preview("Tool Error - Long (collapsed)") {
  ToolErrorView(AppError(String(repeating: "This is a very long error message that exceeds 300 characters. ", count: 10)))
    .frame(minWidth: 400, minHeight: 100)
}

#Preview("Tool Error - ToolError with content") {
  ToolErrorView(ToolError(try! JSON.Value(encoding: [
    ToolsSchema.ACPToolOutput_Content
      .aCPToolOutputMediaContent(.init(content: .aCPToolOutputMediaContentText(.init(text: "Something bad happened:")))),
    ToolsSchema.ACPToolOutput_Content
      .aCPToolOutputMediaContent(.init(content: .aCPToolOutputMediaContentText(.init(text: "404 Not found")))),
  ])))
  .frame(minWidth: 200, minHeight: 50)
}
#endif
