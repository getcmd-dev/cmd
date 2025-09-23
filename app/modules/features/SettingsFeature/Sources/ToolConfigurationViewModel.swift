// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import SettingsServiceInterface
import ToolFoundation

/// Manages tool approval preferences for the Settings UI.
/// Provides a centralized way to view and modify which tools can execute without user approval.
@MainActor
@Observable
public final class ToolConfigurationViewModel {
  init(settingsService: SettingsService, toolsPlugin: ToolsPlugin) {
    self.settingsService = settingsService
    self.toolsPlugin = toolsPlugin

    loadTools()
    observeSettings()
  }

  private(set) var availableTools: [any Tool] = []
  private(set) var toolPreferences: [Settings.ToolPreference] = []

  /// Returns whether a tool is configured to always be approved.
  func isAlwaysApproved(toolName: String) -> Bool {
    toolPreferences.first { $0.toolName == toolName }?.alwaysApprove ?? false
  }

  /// Updates the approval preference for a specific tool.
  func setAlwaysApprove(toolName: String, alwaysApprove: Bool) {
    var currentSettings = settingsService.values()
    currentSettings.setToolPreference(toolName: toolName, alwaysApprove: alwaysApprove)
    settingsService.update(to: currentSettings)
  }

  private let settingsService: SettingsService
  private let toolsPlugin: ToolsPlugin
  private var cancellables = Set<AnyCancellable>()

  private func observeSettings() {
    settingsService.liveValue(for: \.toolPreferences)
      .receive(on: RunLoop.main)
      .sink { [weak self] preferences in
        self?.toolPreferences = preferences
      }
      .store(in: &cancellables)
  }

  private func loadTools() {
    availableTools = toolsPlugin.tools.sorted { $0.displayName < $1.displayName }
  }

}
