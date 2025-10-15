// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import RoutingFoundation
import SettingsFeatureInterface
import SwiftUI

// MARK: - SettingsBuilder

public final class SettingsBuilder: RouteBuilder {
  public init() { }

  public let backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? = { $0.primaryBackground }

  public var routeId: String { SettingsRoute.id }

  @MainActor
  public func build(route _: SettingsRoute, with _: RoutesRegistry) -> any View {
    let viewModel = SettingsViewModel()

    return SettingsView(
      viewModel: viewModel)
  }
}

// MARK: - AIProviderSettingsBuilder

public struct AIProviderSettingsBuilder: RouteBuilder {
  public init() { }

  public var routeId: String { AIProviderSettingsRoute.id }

  public func build(route _: AIProviderSettingsRoute, with _: RoutingFoundation.RoutesRegistry) throws -> any View {
    let settings = LLMSettingsViewModel()
    return AIProvidersView(viewModel: settings)
  }

}

// MARK: - ChatModeSettingsBuilder

public struct ChatModeSettingsBuilder: RouteBuilder {
  public init() { }

  public var routeId: String { ChatModeSettingsRoute.id }

  public func build(route _: ChatModeSettingsRoute, with _: RoutingFoundation.RoutesRegistry) throws -> any View {
    let viewModel = SettingsViewModel()

    return
      ChatModeView(
        chatModeConfigurations: .init(
          get: { viewModel.chatModeConfigurations },
          set: { viewModel.chatModeConfigurations = $0 }),
        toolsPlugin: viewModel.toolsPlugin)
      .padding(.horizontal, SettingsView.Constants.horizontalPadding)
      .padding(.vertical, SettingsView.Constants.verticalPadding)
  }
}
