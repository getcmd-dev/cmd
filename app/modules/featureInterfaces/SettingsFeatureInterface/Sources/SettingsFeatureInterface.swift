// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import RoutingFoundation
import SwiftUI

// MARK: - SettingsRoute

public struct SettingsRoute: Route {
  public var id: String { Self.id }

  public static let name = "settings"
  public static var id: String { name }
  public var name: String { Self.name }

  public init() { }
}

// MARK: - AIProviderSettingsRoute

public struct AIProviderSettingsRoute: Route {
  public var id: String { Self.id }

  public static let name = "ai-providers-settings"
  public static var id: String { name }
  public var name: String { Self.name }

  public init() { }
}

// MARK: - AutocompletionProviderSettingsRoute

public struct AutocompletionProviderSettingsRoute: Route {
  public var id: String { Self.id }

  public static let name = "autocompletion-provider-settings"
  public static var id: String { name }
  public var name: String { Self.name }
  public let showDetailedSettings: Bool

  public init(showDetailedSettings: Bool = false) {
    self.showDetailedSettings = showDetailedSettings
  }

}

// MARK: - ChatModeSettingsRoute

public struct ChatModeSettingsRoute: Route {
  public var id: String { Self.id }

  public static let name = "chat-mode-settings"
  public static var id: String { name }
  public var name: String { Self.name }

  public init() { }
}
