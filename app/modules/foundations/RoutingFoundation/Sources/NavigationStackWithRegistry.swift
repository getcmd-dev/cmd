// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - NavigationStackWithRegistry

public struct NavigationStackWithRegistry: View {
  public init(
    registry: RoutesRegistry,
    rootView: any View,
    navBarBuilder: @escaping @MainActor (@escaping @MainActor () -> Void) -> any View,
    defaultBackgroundColor: @escaping (@Sendable (ColorScheme) -> Color))
  {
    let router = Router(registry: registry)
    navManager = router
    self.rootView = rootView
    self.navBarBuilder = navBarBuilder
    self.defaultBackgroundColor = defaultBackgroundColor
  }

  public var body: some View {
    NavigationStack(path: $navManager.path) {
      AnyView(rootView)
        .navigationDestination(for: AnyRoute.self) { route in
          VStack(spacing: 0) {
            AnyView(navBarBuilder {
              navManager.pop()
            })
            .background(backgroundColor(for: route))

            AnyView(navManager.registry.view(for: route))
              .background(backgroundColor(for: route))

          }.navigationBarBackButtonHidden(true)
        }
    }
    .environment(navManager)
  }

  @Bindable var navManager: Router

  @Environment(\.colorScheme) private var colorScheme

  private let rootView: any View
  private let navBarBuilder: (@escaping @MainActor () -> Void) -> any View
  private let defaultBackgroundColor: @Sendable (ColorScheme) -> Color

  private func backgroundColor(for route: any Route) -> Color {
    navManager.registry.backgroundColor(for: route, colorScheme: colorScheme) ?? defaultBackgroundColor(colorScheme)
  }

}
