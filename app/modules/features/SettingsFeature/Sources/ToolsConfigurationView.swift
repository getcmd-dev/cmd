// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import ToolFoundation

// MARK: - ToolsConfigurationView

struct ToolsConfigurationView: View {

  @Bindable var viewModel: ToolConfigurationViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Tool Permissions")
        .font(.headline)
        .padding(.bottom, 8)

      if viewModel.availableTools.isEmpty {
        Text("No tools available")
          .foregroundColor(.secondary)
          .padding(.vertical, 20)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.availableTools, id: \.name) { tool in
              ToolRow(
                tool: tool,
                isAlwaysApproved: viewModel.isAlwaysApproved(toolName: tool.name),
                onToggle: { isEnabled in
                  viewModel.setAlwaysApprove(toolName: tool.name, alwaysApprove: isEnabled)
                })
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .padding()
  }
}

// MARK: - ToolRow

private struct ToolRow: View {

  let tool: any Tool
  let isAlwaysApproved: Bool
  let onToggle: (Bool) -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(tool.displayName)
          .font(.system(size: 13, weight: .medium))
        if !tool.shortDescription.isEmpty {
          Text(tool.shortDescription)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Toggle("", isOn: Binding(
        get: { isAlwaysApproved },
        set: { onToggle($0) }))
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .labelsHidden()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }
}
