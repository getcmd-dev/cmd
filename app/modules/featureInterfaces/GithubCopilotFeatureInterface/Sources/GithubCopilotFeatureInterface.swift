// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import RoutingFoundation
import SwiftUI

// MARK: - GithubCopilotRoute

public struct GithubCopilotRoute: Route {
  public var id: String { Self.id }

  public static let name = "githubCopilot"
  public static var id: String { name }
  public var name: String { Self.name }

  public init() { }
}
