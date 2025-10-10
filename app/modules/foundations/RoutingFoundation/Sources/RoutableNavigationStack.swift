// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - RoutableNavigationStack

/// A navigation stack that integrates with the RoutingFoundation system.
///
/// This view bridges SwiftUI's `NavigationStack` with the `Route`/`RouteBuilder` pattern,
/// providing a customizable navigation experience with route-specific backgrounds and
/// custom navigation bars.
///
/// ## Usage
///
/// ```swift
/// RoutableNavigationStack(
///   registry: routeRegistry,
///   rootView: HomeView(),
///   navBarBuilder: { popAction in
///     CustomNavBar(onBackPressed: popAction)
///   },
///   defaultBackgroundColor: { colorScheme in
///     colorScheme == .dark ? .black : .white
///   }
/// )
/// ```
///
/// ## Router Access
///
/// The router is expected to be injected into the SwiftUI environment and can be
/// accessed by child views:
///
/// ```swift
/// @Environment(Router.self) private var router
/// ```
///
/// ## Customization
///
/// - **Navigation Bar**: Provide a custom navigation bar via `navBarBuilder`
/// - **Background Colors**: Set default and per-route background colors
/// - **Root View**: The initial view shown when the navigation stack is empty
public struct RoutableNavigationStack: View {

  /// Creates a navigation stack integrated with the routing system.
  ///
  /// - Parameters:
  ///   - router: The `Router` that handles navigation events. Routes should be
  ///     registered to its registry before creating the navigation stack.
  ///   - rootView: The initial view shown when the navigation stack is empty.
  ///   - navBarBuilder: A closure that constructs the custom navigation bar for pushed routes.
  ///     Receives a closure to trigger back navigation.
  ///   - defaultBackgroundColor: The default background color for routes that don't specify
  ///     their own `backgroundColor`. Receives the current color scheme.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let registry = RoutesRegistry()
  /// registry.registerRoutes()
  /// let router = Router(registry: registry)
  ///
  /// RoutableNavigationStack(
  ///   router: router,
  ///   rootView: HomeView(),
  ///   navBarBuilder: { popAction in
  ///     HStack {
  ///       Button(action: popAction) {
  ///         Image(systemName: "chevron.left")
  ///       }
  ///       Spacer()
  ///     }
  ///   },
  ///   defaultBackgroundColor: { _ in .white }
  /// )
  /// ```
  public init(
    router: Router,
    rootView: any View,
    navBarBuilder: @escaping @MainActor (@escaping @MainActor () -> Void) -> any View,
    defaultBackgroundColor: @escaping (@Sendable (ColorScheme) -> Color))
  {
    self.router = router
    self.rootView = rootView
    self.navBarBuilder = navBarBuilder
    self.defaultBackgroundColor = defaultBackgroundColor
  }

  public var body: some View {
    NavigationStack(path: $router.path) {
      AnyView(rootView)
        .navigationDestination(for: AnyRoute.self) { route in
          VStack(spacing: 0) {
            // Custom navigation bar with back action
            AnyView(navBarBuilder {
              router.pop()
            })
            .background(backgroundColor(for: route))

            // Route's view content
            AnyView(router.registry.view(for: route))
              .background(backgroundColor(for: route))

          }.navigationBarBackButtonHidden(true)
        }
    }
    .environment(router)
  }

  /// The router managing navigation state.
  ///
  /// Marked `@Bindable` to allow SwiftUI to observe changes to the navigation path.
  @Bindable var router: Router

  @Environment(\.colorScheme) private var colorScheme

  private let rootView: any View
  private let navBarBuilder: (@escaping @MainActor () -> Void) -> any View
  private let defaultBackgroundColor: @Sendable (ColorScheme) -> Color

  /// Returns the background color for the given route.
  ///
  /// Uses the route's custom background color if specified, otherwise falls back
  /// to the default background color.
  private func backgroundColor(for route: any Route) -> Color {
    router.registry.backgroundColor(for: route, colorScheme: colorScheme) ?? defaultBackgroundColor(colorScheme)
  }

}
