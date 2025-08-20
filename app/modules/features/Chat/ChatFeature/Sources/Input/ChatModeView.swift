// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import DLS
import SwiftUI

private let iconSize: CGFloat = 11

// MARK: - AgentModeView

struct AgentModeView: View {
  var body: some View {
    HStack(spacing: 3) {
      Icon(systemName: ChatMode.agent.systemImageName)
        .frame(width: iconSize, height: iconSize)
      Text(ChatMode.agent.name)
    }
  }
}

// MARK: - AskModeView

struct AskModeView: View {
  var body: some View {
    HStack(spacing: 3) {
      Icon(systemName: ChatMode.ask.systemImageName)
        .frame(width: iconSize, height: iconSize)
      Text(ChatMode.ask.name)
    }
  }
}
