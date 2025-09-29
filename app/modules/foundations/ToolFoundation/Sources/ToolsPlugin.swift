// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import ThreadSafe

@ThreadSafe
public final class ToolsPlugin: Sendable {

  #if DEBUG
  public init() { }
  #else
  init() { }
  #endif

  /// All registered tools in the plugin.
  /// - Returns: An array containing all tools currently registered in the plugin.
  public var tools: [any Tool] {
    Array(registry.values)
  }

  /// Returns tools that are available for the specified chat mode.
  /// - Parameter mode: The chat mode to filter tools for.
  /// - Returns: An array of tools that are available in the specified chat mode.
  public func tools(for mode: ChatMode) -> [any Tool] {
    Array(registry.values).filter { $0.isAvailable(in: mode) }
  }

  /// Registers a tool in the plugin registry.
  /// - Parameter tool: The tool to register. The tool's name will be used as the registry key.
  public func plugIn(tool: any Tool) {
    registry[tool.name] = tool
  }

  /// Removes a tool from the plugin registry.
  /// - Parameter name: The name of the tool to remove from the registry.
  public func unplug(toolNamed name: String) {
    registry.removeValue(forKey: name)
  }

  /// Retrieves a tool by name from the registry or fallback matchers.
  /// - Parameter name: The name of the tool to retrieve.
  /// - Returns: The tool if found in the registry or through fallback matchers, otherwise nil.
  public func tool(named name: String) -> (any Tool)? {
    if let tool = registry[name] {
      return tool
    }
    return nil
  }

  private var registry = [String: any Tool]()

}
