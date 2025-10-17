// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ThreadSafe

@ThreadSafe
public final class ToolsPlugin: Sendable {

  public init() { }

  /// All registered tools in the plugin.
  /// - Returns: An array containing all tools currently registered in the plugin.
  public var tools: [any Tool] {
    Array(registry.values)
  }

  /// Returns tools that match the specified tool reference IDs.
  /// - Parameter referenceIds: The list of tool reference IDs to retrieve.
  /// - Returns: An array of tools that match the specified reference IDs.
  public func tools(withReferenceIds referenceIds: [String]) -> [any Tool] {
    let referenceIds = Set(referenceIds)
    return registry.values.filter { referenceIds.contains($0.referenceId) }
  }

  /// Returns the default set of tools available for a given chat mode.
  /// This uses each tool's `isAvailableByDefault(in:)` method to determine inclusion.
  /// - Parameter mode: The chat mode to get default tools for.
  /// - Returns: An array of tools that are available by default in the specified mode.
  public func defaultTools(for mode: ChatMode) -> [any Tool] {
    Array(registry.values).filter { $0.isAvailableByDefault(in: mode) }
  }

  /// Registers a tool in the plugin registry.
  /// - Parameter tool: The tool to register. The tool's name will be used as the registry key.
  public func plugIn(tool: any Tool) {
    registry[tool.id] = tool
  }

  /// Removes a tool from the plugin registry.
  /// - Parameter id: The ID of the tool to retrieve.
  public func unplug(toolId id: String) {
    registry.removeValue(forKey: id)
  }

  /// Retrieves a tool by name from the registry or fallback matchers.
  /// - Parameter name: The name of the tool to retrieve.
  /// - Returns: The tool if found in the registry or through fallback matchers, otherwise nil.
  @available(*, deprecated, renamed: "tool(byId:)", message: "Use tool(byId:) instead")
  public func tool(named name: String) -> (any Tool)? {
    registry.values.first { $0.name == name }
  }

  /// Retrieves a tool by ID from the registry.
  /// - Parameter id: The ID of the tool to retrieve.
  /// - Returns: The tool if found in the registry, otherwise nil.
  public func tool(byId id: String) -> (any Tool)? {
    registry[id]
  }

  private var registry = [String: any Tool]()

}
