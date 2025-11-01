// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - JRPCServiceDependencyKey

public final class JRPCServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: JRPCService = MockJRPCService()
  #else
  /// This is not read outside of DEBUG
  public static let testValue: JRPCService = () as! JRPCService
  #endif
}

extension DependencyValues {
  public var jrpcService: JRPCService {
    get { self[JRPCServiceDependencyKey.self] }
    set { self[JRPCServiceDependencyKey.self] = newValue }
  }
}
