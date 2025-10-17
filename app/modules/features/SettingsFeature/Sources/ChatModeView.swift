// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import Dependencies
import DLS
import MCPService
import SettingsServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ChatModeView

struct ChatModeView: View {

  @Binding var chatModeConfigurations: [String: SettingsServiceInterface.Settings.ChatModeConfiguration]

  let toolsPlugin: ToolsPlugin

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Chat mode selector (no label to avoid "Chat Mode" repetition)
        Picker("", selection: $selectedMode) {
          ForEach(ChatMode.allCases) { mode in
            Text(mode.name)
              .tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        // Configuration for selected mode
        ChatModeConfigurationView(
          mode: selectedMode,
          configuration: Binding(
            get: {
              // Return existing config, or default config with nil tools (meaning use defaults)
              chatModeConfigurations[selectedMode.id] ?? SettingsServiceInterface.Settings.ChatModeConfiguration(
                customInstructions: nil,
                availableToolIds: nil)
            },
            set: { newConfig in
              chatModeConfigurations[selectedMode.id] = newConfig
            }),
          toolsPlugin: toolsPlugin)

        Spacer(minLength: 20)
      }
    }
  }

  @State private var selectedMode = ChatMode.agent

}

// MARK: - ChatModeConfigurationView

struct ChatModeConfigurationView: View {

  let mode: ChatMode
  @Binding var configuration: SettingsServiceInterface.Settings.ChatModeConfiguration
  let toolsPlugin: ToolsPlugin

  @State private var isCustomInstructionsExpanded = false
  @State private var isToolsExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Mode description under the picker
      Text(mode.description)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding(.bottom, 8)

      // Custom instructions
      CustomInstructionSection(
        text: Binding(
          get: { configuration.customInstructions ?? "" },
          set: { configuration.customInstructions = $0.isEmpty ? nil : $0 }),
        isExpanded: $isCustomInstructionsExpanded,
        iconName: "text.alignleft",
        title: "Custom Instructions",
        subtitle: "Provide extra instructions for \(mode.name) Mode. These are added to the default system prompt.")

      // Available tools
      ToolSelectionSection(
        selectedToolReferenceIds: Binding(
          get: {
            // If availableToolIds is nil, show the computed defaults, but don't save them until user makes changes
            if let toolIds = configuration.availableToolIds {
              Set(toolIds)
            } else {
              // Show defaults computed from toolsPlugin
              Set(toolsPlugin.defaultTools(for: mode).map(\.referenceId))
            }
          },
          set: { newToolIds in
            // When user changes selection, save it (this transitions from nil to an explicit array)
            configuration.availableToolIds = Array(Set(newToolIds)).sorted()
          }),
        allTools: toolsPlugin.tools,
        isExpanded: $isToolsExpanded,
        mode: mode,
        toolsPlugin: toolsPlugin)
    }
  }
}

// MARK: - ToolSelectionSection

struct ToolSelectionSection: View {

  @Binding var selectedToolReferenceIds: Set<String>
  let allTools: [any Tool]
  @Binding var isExpanded: Bool
  let mode: ChatMode
  let toolsPlugin: ToolsPlugin

  private var organizedTools: OrganizedTools {
    organizeTools(allTools)
  }

  private var totalToolCount: Int {
    organizedTools.nonExternalNonMCPTools.count +
      organizedTools.unmatchedExternalTools.count +
      organizedTools.mcpToolsByServer.values.reduce(0) { $0 + $1.count }
  }

  private var selectedToolCount: Int {
    selectedToolReferenceIds.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: { isExpanded.toggle() }) {
        HStack {
          Image(systemName: "wrench.and.screwdriver")
            .frame(width: 16, height: 16)
          Text("Available Tools")
            .font(.headline)
          Spacer()
          if !isExpanded {
            Text("\(selectedToolCount) of \(totalToolCount) enabled")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .foregroundColor(.primary)
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Select which tools are available in \(mode.name) Mode. Tools will still require permission to run.")
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
            Button("Reset to Default") {
              resetToDefault()
            }
            .font(.caption)
          }

          VStack(alignment: .leading, spacing: 8) {
            // Non-external, non-MCP tools first
            ForEach(organizedTools.nonExternalNonMCPTools, id: \.id) { tool in
              ChatModeToolRow(
                tool: tool,
                isSelected: toolBinding(for: tool.referenceId))
            }

            // External tools (not matched by non-external) next
            if !organizedTools.unmatchedExternalTools.isEmpty {
              if !organizedTools.nonExternalNonMCPTools.isEmpty {
                Divider()
                  .padding(.vertical, 4)
              }
              ForEach(organizedTools.unmatchedExternalTools, id: \.id) { tool in
                ChatModeToolRow(
                  tool: tool,
                  isSelected: toolBinding(for: tool.referenceId))
              }
            }

            // MCP tools grouped by server
            if !organizedTools.mcpToolsByServer.isEmpty {
              Divider()
                .padding(.vertical, 4)

              ForEach(Array(organizedTools.mcpToolsByServer.keys.sorted()), id: \.self) { serverName in
                if let tools = organizedTools.mcpToolsByServer[serverName] {
                  MCPServerToolsSection(
                    serverName: serverName,
                    tools: tools,
                    selectedToolReferenceIds: $selectedToolReferenceIds)
                }
              }
            }
          }
          .padding(8)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1))
        }
      }
    }
  }

  private func toolBinding(for referenceId: String) -> Binding<Bool> {
    Binding(
      get: { selectedToolReferenceIds.contains(referenceId) },
      set: { isSelected in
        if isSelected {
          selectedToolReferenceIds.insert(referenceId)
        } else {
          selectedToolReferenceIds.remove(referenceId)
        }
      })
  }

  private func resetToDefault() {
    // Reset to default: select all tools that are available by default in this mode
    selectedToolReferenceIds = Set(
      toolsPlugin.defaultTools(for: mode).map(\.referenceId))
  }

  private func organizeTools(_ tools: [any Tool]) -> OrganizedTools {
    var nonExternalNonMCPTools = [any Tool]()
    var externalTools = [any Tool]()
    var mcpToolsByServer = [String: [MCPTool]]()

    // Collect all non-external reference IDs
    let nonExternalReferenceIds = Set(tools.filter { !$0.isExternalTool }.map(\.referenceId))

    for tool in tools {
      // Check if it's an MCP tool
      if let mcpTool = tool as? MCPTool {
        mcpToolsByServer[mcpTool.serverName, default: []].append(mcpTool)
      } else if tool.isExternalTool {
        // External tool - only add if no non-external tool has the same referenceId
        if !nonExternalReferenceIds.contains(tool.referenceId) {
          externalTools.append(tool)
        }
      } else {
        // Non-external, non-MCP tool
        nonExternalNonMCPTools.append(tool)
      }
    }

    return OrganizedTools(
      nonExternalNonMCPTools: nonExternalNonMCPTools.sorted { $0.displayName < $1.displayName },
      unmatchedExternalTools: externalTools.sorted { $0.displayName < $1.displayName },
      mcpToolsByServer: mcpToolsByServer.mapValues { $0.sorted { $0.displayName < $1.displayName } })
  }
}

// MARK: - OrganizedTools

private struct OrganizedTools {
  let nonExternalNonMCPTools: [any Tool]
  let unmatchedExternalTools: [any Tool]
  let mcpToolsByServer: [String: [MCPTool]]
}

// MARK: - MCPServerToolsSection

struct MCPServerToolsSection: View {
  let serverName: String
  let tools: [MCPTool]
  @Binding var selectedToolReferenceIds: Set<String>

  private var allSelected: Bool {
    tools.allSatisfy { selectedToolReferenceIds.contains($0.referenceId) }
  }

  private var someSelected: Bool {
    tools.contains { selectedToolReferenceIds.contains($0.referenceId) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Server header with select all toggle
      HStack {
        MCPIcon()
          .frame(width: 16, height: 16)
          .foregroundColor(.secondary)
        Text(serverName)
          .font(.subheadline)
          .fontWeight(.medium)
        Spacer()
        Button(action: toggleAllTools) {
          HStack(spacing: 4) {
            Text(allSelected ? "Deselect All" : "Select All")
              .font(.caption)
            Image(systemName: allSelected ? "checkmark.square" : (someSelected ? "minus.square" : "square"))
              .font(.system(size: 14))
          }
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)

      // Tools for this server (indented)
      ForEach(tools, id: \.id) { tool in
        HStack {
          Spacer()
            .frame(width: 20)
          ChatModeToolRow(
            tool: tool,
            toolDisplayName: tool.originalName,
            isSelected: Binding(
              get: { selectedToolReferenceIds.contains(tool.referenceId) },
              set: { isSelected in
                if isSelected {
                  selectedToolReferenceIds.insert(tool.referenceId)
                } else {
                  selectedToolReferenceIds.remove(tool.referenceId)
                }
              }))
        }
      }
    }
  }

  private func toggleAllTools() {
    if allSelected {
      // Deselect all
      for tool in tools {
        selectedToolReferenceIds.remove(tool.referenceId)
      }
    } else {
      // Select all
      for tool in tools {
        selectedToolReferenceIds.insert(tool.referenceId)
      }
    }
  }
}

// MARK: - ChatModeToolRow

struct ChatModeToolRow: View {

  let tool: any Tool
  var toolDisplayName: String? = nil
  @Binding var isSelected: Bool

  var body: some View {
    HStack {
      Toggle(isOn: $isSelected) {
        VStack(alignment: .leading, spacing: 2) {
          Text(toolDisplayName ?? tool.displayName)
            .font(.body)
          Text(tool.shortDescription)
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      .toggleStyle(.checkbox)
    }
  }
}

// MARK: - CustomInstructionSection

struct CustomInstructionSection: View {

  init(
    text: Binding<String>,
    isExpanded: Binding<Bool>,
    iconName: String,
    title: String,
    subtitle: String,
    minHeight: CGFloat = 100,
    maxHeight: CGFloat = 200,
    fontSize: CGFloat = 13)
  {
    _text = text
    _isExpanded = isExpanded
    self.iconName = iconName
    self.title = title
    self.subtitle = subtitle
    self.minHeight = minHeight
    self.maxHeight = maxHeight
    self.fontSize = fontSize
  }

  @Binding var text: String
  @Binding var isExpanded: Bool

  let iconName: String
  let title: String
  let subtitle: String
  let minHeight: CGFloat
  let maxHeight: CGFloat
  let fontSize: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: { isExpanded.toggle() }) {
        HStack {
          Icon(systemName: iconName)
            .frame(width: 16, height: 16)
          Text(title)
            .font(.headline)
          Spacer()
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .foregroundColor(.primary)
      }
      .buttonStyle(.plain)

      if isExpanded {
        Text(subtitle)
          .font(.caption)
          .foregroundColor(.secondary)
        TextEditor(text: $text)
          .font(.system(size: fontSize))
          .scrollContentBackground(.hidden)
          .frame(minHeight: minHeight, maxHeight: maxHeight)
          .padding(8)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1))
      }
    }
  }
}

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
