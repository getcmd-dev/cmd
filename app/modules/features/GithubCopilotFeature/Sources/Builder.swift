// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import GithubCopilotFeatureInterface
import RoutingFoundation
import SwiftUI

// MARK: - GithubCopilotBuilder

public final class GithubCopilotBuilder: RouteBuilder {
  public init() { }

  public let backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? = { $0.primaryBackground }

  public var routeId: String { GithubCopilotRoute.id }

  @MainActor
  public func build(route: GithubCopilotRoute, with _: RoutesRegistry) -> any View {
    let viewModel = GithubCopilotStatusViewModel()

    return GithubCopilotStatusView(
      viewModel: viewModel,
      isExpanded: route.isExpanded)
  }
}
