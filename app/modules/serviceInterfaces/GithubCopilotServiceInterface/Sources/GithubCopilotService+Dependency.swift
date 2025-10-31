// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation

import Dependencies

// MARK: - GithubCopilotServiceDependencyKey

public struct GithubCopilotServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: GithubCopilotService = MockGithubCopilotService()
  #else
  public static let testValue: GithubCopilotService = () as! GithubCopilotService
  #endif
}

// MARK: - DependencyValues + GithubCopilotService

extension DependencyValues {
  public var githubCopilotService: GithubCopilotService {
    get { self[GithubCopilotServiceDependencyKey.self] }
    set { self[GithubCopilotServiceDependencyKey.self] = newValue }
  }
}
