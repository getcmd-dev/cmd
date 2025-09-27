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

  public var tools: [any Tool] {
    Array(registry.values)
  }

  public func tools(for mode: ChatMode) -> [any Tool] {
    Array(registry.values).filter { $0.isAvailable(in: mode) }
  }

  public func plugIn(tool: any Tool) {
    registry[tool.name] = tool
  }

  public func unplug(toolNamed name: String) {
    registry.removeValue(forKey: name)
  }

  public func tool(named name: String) -> (any Tool)? {
    registry[name]
  }

  private var registry = [String: any Tool]()

}
