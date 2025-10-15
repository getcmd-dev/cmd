// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation

import Dependencies

// MARK: - MCPServiceDependencyKey

public struct MCPServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: MCPService = MockMCPService()
  #else
  public static let testValue: MCPService = () as! MCPService
  #endif
}

// MARK: - DependencyValues + MCPService

extension DependencyValues {
  public var mcpService: MCPService {
    get { self[MCPServiceDependencyKey.self] }
    set { self[MCPServiceDependencyKey.self] = newValue }
  }
}
