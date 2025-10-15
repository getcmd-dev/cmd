// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import SettingsServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
import ToolFoundation
@testable import SettingsServiceToolsAdapter

// MARK: - ServiceAdapterTests

struct ServiceAdapterTests {

  // MARK: - Test: Returns default tools when no configuration exists

  @Test("Returns default tools when no configuration exists")
  func test_returnsDefaultToolsWhenNoConfiguration() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false))
    let mockPlugin = createMockToolsPlugin()

    // Test
    let tools = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify
    #expect(tools.count == 2)
    #expect(tools.map(\.referenceId).contains("tool1"))
    #expect(tools.map(\.referenceId).contains("tool2"))
  }

  // MARK: - Test: Returns custom tools when availableToolIds is configured

  @Test("Returns custom tools when availableToolIds is configured")
  func test_returnsCustomToolsWhenConfigured() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.agent.id: .init(customInstructions: nil, availableToolIds: ["tool1"])],
      knownToolReferenceIds: ["tool1", "tool2", "tool3"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    let tools = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify
    #expect(tools.count == 1)
    #expect(tools.first?.referenceId == "tool1")
  }

  // MARK: - Test: Returns default tools when availableToolIds is nil

  @Test("Returns default tools when availableToolIds is nil")
  func test_returnsDefaultToolsWhenAvailableToolIdsIsNil() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.agent.id: .init(customInstructions: "Test", availableToolIds: nil)]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    let tools = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify - should return default tools since availableToolIds is nil
    #expect(tools.count == 2)
    #expect(tools.map(\.referenceId).contains("tool1"))
    #expect(tools.map(\.referenceId).contains("tool2"))
  }

  // MARK: - Test: Returns empty array when availableToolIds is empty array

  @Test("Returns empty array when availableToolIds is empty array")
  func test_returnsEmptyArrayWhenAvailableToolIdsIsEmpty() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.agent.id: .init(customInstructions: nil, availableToolIds: [])],
      knownToolReferenceIds: ["tool1", "tool2", "tool3"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    let tools = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify
    #expect(tools.isEmpty)
  }

  // MARK: - Test: Tracks and updates knownToolReferenceIds when new tools are discovered

  @Test("Tracks and updates knownToolReferenceIds when new tools are discovered")
  func test_tracksNewToolsInKnownToolReferenceIds() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      knownToolReferenceIds: ["tool1"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify
    #expect(mockSettings.values().knownToolReferenceIds.sorted() == ["tool1", "tool2", "tool3"])
  }

  // MARK: - Test: Adds new default tools to existing custom configurations

  @Test("Adds new default tools to existing custom configurations")
  func test_addsNewDefaultToolsToCustomConfigurations() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.agent.id: .init(customInstructions: nil, availableToolIds: ["tool1"])],
      knownToolReferenceIds: ["tool1"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify - tool2 is default for agent mode, so it should be added
    let config = mockSettings.values().chatModeConfigurations[ChatMode.agent.id]
    #expect(config?.availableToolIds?.sorted() == ["tool1", "tool2"])
  }

  // MARK: - Test: Does not add new tools to modes where they are not default

  @Test("Does not add new tools to modes where they are not default")
  func test_doesNotAddNewToolsToNonDefaultModes() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.ask.id: .init(customInstructions: nil, availableToolIds: ["tool1"])],
      knownToolReferenceIds: ["tool1"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .ask, toolsPlugin: mockPlugin)

    // Verify - tool2 is NOT default for ask mode (only for agent), so it should NOT be added
    let config = mockSettings.values().chatModeConfigurations[ChatMode.ask.id]
    #expect(config?.availableToolIds == ["tool1"])
  }

  // MARK: - Test: Does not modify configurations when availableToolIds is nil

  @Test("Does not modify configurations when availableToolIds is nil")
  func test_doesNotModifyConfigurationsWhenAvailableToolIdsIsNil() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [ChatMode.agent.id: .init(customInstructions: "Test", availableToolIds: nil)],
      knownToolReferenceIds: ["tool1"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify - availableToolIds should remain nil (user hasn't explicitly configured)
    let config = mockSettings.values().chatModeConfigurations[ChatMode.agent.id]
    #expect(config?.availableToolIds == nil)
  }

  // MARK: - Test: Only calls update when new tools are discovered

  @Test("Only calls update when new tools are discovered")
  func test_onlyCallsUpdateWhenNewToolsDiscovered() {
    // Setup - all tools already known
    let initialSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      knownToolReferenceIds: ["tool1", "tool2", "tool3"])
    let mockSettings = MockSettingsService(initialSettings)
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify - settings should not have changed since all tools are known
    #expect(mockSettings.values() == initialSettings)
  }

  // MARK: - Test: Calls update when new tools are discovered

  @Test("Calls update when new tools are discovered")
  func test_callsUpdateWhenNewToolsDiscovered() {
    // Setup
    let initialSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      knownToolReferenceIds: ["tool1"])
    let mockSettings = MockSettingsService(initialSettings)
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify - knownToolReferenceIds should have been updated
    #expect(mockSettings.values().knownToolReferenceIds.sorted() == ["tool1", "tool2", "tool3"])
  }

  // MARK: - Test: Handles multiple chat modes with different configurations

  @Test("Handles multiple chat modes with different configurations")
  func test_handlesMultipleChatModesWithDifferentConfigurations() {
    // Setup
    let mockSettings = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: false,
      chatModeConfigurations: [
        ChatMode.agent.id: .init(customInstructions: nil, availableToolIds: ["tool1"]),
        ChatMode.ask.id: .init(customInstructions: nil, availableToolIds: ["tool1"]),
      ],
      knownToolReferenceIds: ["tool1"]))
    let mockPlugin = createMockToolsPlugin()

    // Test
    _ = mockSettings.tools(availableIn: .agent, toolsPlugin: mockPlugin)

    // Verify
    let finalSettings = mockSettings.values()
    // Agent mode: tool2 is default, should be added
    let agentConfig = finalSettings.chatModeConfigurations[ChatMode.agent.id]
    #expect(agentConfig?.availableToolIds?.sorted() == ["tool1", "tool2"])

    // Ask mode: tool2 is NOT default, should NOT be added
    let askConfig = finalSettings.chatModeConfigurations[ChatMode.ask.id]
    #expect(askConfig?.availableToolIds == ["tool1"])
  }
}

// MARK: - Mock ToolsPlugin Helper

func createMockToolsPlugin() -> ToolsPlugin {
  let plugin = ToolsPlugin()
  plugin.plugIn(tool: TestTool(name: "tool1", referenceId: "tool1", availableByDefaultIn: [.agent, .ask]))
  plugin.plugIn(tool: TestTool(name: "tool2", referenceId: "tool2", availableByDefaultIn: [.agent]))
  plugin.plugIn(tool: TestTool(name: "tool3", referenceId: "tool3", availableByDefaultIn: []))
  return plugin
}
