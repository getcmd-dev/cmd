// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import SettingsServiceInterface
import ToolFoundation

extension SettingsService {
  /// Return the list of tools available in the given chat mode.
  /// This method reconciles tools configured as available by the user for a given chat mode
  /// with new tools that might have been added after the configuration.
  /// - Note: This method may update settings as a side effect if new tools are discovered.
  public func tools(availableIn chatMode: ChatMode, toolsPlugin: ToolsPlugin) -> [any Tool] {
    // check if we have new tools available that didn't exist when the
    // availableTools setting was set.
    var settings = values()
    let toolReferenceIds = Set(toolsPlugin.tools.map(\.referenceId))
    let knownToolIds = Set(settings.knownToolReferenceIds)
    let newTools = toolReferenceIds.subtracting(knownToolIds)
    if !newTools.isEmpty {
      // New tools are available, update existing user configs with default values.
      for chatModeId in settings.chatModeConfigurations.keys {
        guard let chatMode = ChatMode.allCases.first(where: { $0.id == chatModeId }) else { continue }
        let defaultTools = toolsPlugin.defaultTools(for: chatMode).map(\.referenceId)
        let newToolsAvailableInChatMode = newTools.filter { defaultTools.contains($0) }
        settings.chatModeConfigurations[chatModeId]?.availableToolIds?.append(contentsOf: newToolsAvailableInChatMode)
      }
      settings.knownToolReferenceIds = (settings.knownToolReferenceIds + Array(newTools)).sorted()
      update(to: settings)
    }

    if let availableToolIds = settings.chatModeConfigurations[chatMode.id]?.availableToolIds {
      // User has customized the tool list
      return toolsPlugin.tools(withReferenceIds: availableToolIds)
    } else {
      // No custom configuration (availableToolIds is nil) - use default tools for this mode
      return toolsPlugin.defaultTools(for: chatMode)
    }
  }
}
