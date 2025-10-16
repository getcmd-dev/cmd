// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import SwiftUI
import ToolFoundation

// MARK: - Preview
#if DEBUG
#Preview {
  @Dependency(\.toolsPlugin) var toolsPlugin
  return ChatModeView(
    chatModeConfigurations: .constant([:]),
    toolsPlugin: toolsPlugin)
    .frame(width: 700, height: 700)
    .padding()
}
#endif
