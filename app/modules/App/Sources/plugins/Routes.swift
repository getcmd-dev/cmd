// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import RoutingFoundation
import SettingsFeature

extension RoutesRegistry {
  func registerRoutes() {
    register(routeBuilder: SettingsBuilder())
    register(routeBuilder: AIProviderSettingsBuilder())
  }
}
