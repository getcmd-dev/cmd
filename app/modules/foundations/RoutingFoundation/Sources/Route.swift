// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Observation
@preconcurrency import SwiftUI

/// Routing allows for the decoupling between a feature's implementation and its usage.
/// The implementing module, typically a `Feature` module, defines the view and its state management.
/// It provides a `RouteBuilder` that can resolve a `Route` of a specific type to a `View`.
/// The interface module typically only describe the `Route` type and its configuration parameters.
/// The top level scope is responsible for registering all available features to their given routes.
/// Then, a feature can be used with little dependencies as:
///
/// ```swift
/// import SettingsFeatureInterface
///
/// struct SomeView: View {
///   var body: some View {
///     // Navigate to a new screen
///     Button { router.navigate(to: SettingsRoute()) }
///     ...
///     // Embed a view within the current view
///     AnyView(router.embed(route: SettingsStatusRoute())
///   }
///   @Environment(Router.self) private var router
/// }
/// ```

// MARK: - Route

/// Represents a navigation destination in the routing system.
///
/// Routes serve as type-safe identifiers for navigation targets. Each route must provide
/// a unique identity value and a human-readable name for debugging purposes.
///
/// ## Example
///
/// ```swift
/// struct SettingsRoute: Route {
///   var id: String { "settings" }
///   var name: String { "Settings" }
/// }
/// ```
public protocol Route: Sendable, Hashable {
  associatedtype RouteID: Hashable

  /// The unique identifier for this route type.
  ///
  /// This value is used to match a route with a route builder.
  var id: RouteID { get }

  /// A human-readable name for this route.
  ///
  /// Used in debugging, logging, and error messages.
  var name: String { get }
}

// MARK: - RouteBuilder

/// A factory responsible for constructing views for a specific route type.
///
/// RouteBuilders decouple route definitions from view construction, enabling features to
/// define their routes in interface modules while keeping view implementations in feature modules.
///
/// ## Example
///
/// ```swift
/// struct SettingsBuilder: RouteBuilder {
///   var routeId: String { "settings" }
///
///   @MainActor
///   func build(route: SettingsRoute, with registry: RoutesRegistry) throws -> any View {
///     SettingsView(viewModel: SettingsViewModel())
///   }
///
///   var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? {
///     { colorScheme in
///       colorScheme == .dark ? .black : .white
///     }
///   }
/// }
/// ```
public protocol RouteBuilder: Sendable {
  associatedtype Route: RoutingFoundation.Route

  /// The unique identifier for the route this builder creates.
  ///
  /// Must match the `id` of the associated `Route` type. Used by the registry
  /// to map route instances to their builders.
  var routeId: Route.RouteID { get }

  /// Optional closure providing a custom background color for this route.
  ///
  /// If `nil`, the default navigation background color is used. The closure receives
  /// the current color scheme and should return the appropriate color.
  var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? { get }

  /// Constructs the view for the given route.
  ///
  /// - Parameters:
  ///   - route: The route instance to build a view for. May contain navigation parameters.
  ///   - registry: The routes registry, allowing registration of nested/child routes.
  /// - Returns: The constructed view for this route.
  /// - Throws: Any error encountered during view construction.
  @MainActor
  func build(route: Route, with registry: RoutesRegistry) throws -> any View
}

extension RouteBuilder {
  /// Default implementation returns `nil`, using the navigation's default background color.
  public var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? { nil }
}

// MARK: - RoutesRegistry

/// Central registry mapping route identifiers to their builders.
///
/// The `RoutesRegistry` maintains a mapping of route IDs to `RouteBuilder` instances,
/// enabling dynamic view construction during navigation.
///
/// ## Registration
///
/// Routes should be registered at app startup before any navigation occurs, typically
/// via an extension method like `registerRoutes()`:
///
/// ```swift
/// extension RoutesRegistry {
///   func registerRoutes() {
///     register(routeBuilder: SettingsBuilder())
///     register(routeBuilder: ChatBuilder())
///   }
/// }
/// ```
@MainActor
public final class RoutesRegistry: Sendable {
  public init() { }

  /// Registers a route builder for top-level navigation.
  ///
  /// - Parameter routeBuilder: The builder to register. Its `routeId` must match
  ///   the `id` of the `Route` type it builds.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let registry = RoutesRegistry()
  /// registry.register(routeBuilder: SettingsBuilder())
  /// ```
  public func register(routeBuilder: any RouteBuilder) {
    registry[routeBuilder.id] = routeBuilder
  }

  /// Registers a subroute builder for nested navigation.
  ///
  /// - Note: Currently behaves identically to `register(routeBuilder:)`.
  ///   Future versions will scope subroutes to the current navigation path.
  /// - Parameter subrouteBuilder: The builder to register.
  /// - TODO: Scope this to the current navigation path.
  public func register(subrouteBuilder: any RouteBuilder) {
    // Todo: scope this to the current path.
    registry[subrouteBuilder.id] = subrouteBuilder
  }

  /// Constructs and returns the view for the given route.
  ///
  /// - Parameter route: The route to build a view for.
  /// - Returns: The view constructed by the route's registered builder, or an error view
  ///   if the route is not registered.
  ///
  /// ## Error Handling
  ///
  /// - In Xcode previews: Returns a `Text` view showing the missing route name
  /// - In production: Logs an error and returns `EmptyView()`
  func view(for route: any Route) -> any View {
    guard let builder = registry[route.hashId] else {
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        // In Xcode previews, route registration may not occur since full app initialization doesn't run.
        // Show a placeholder to help developers identify missing route registrations.
        return Text("Missing route: \(route.name)")
      } else {
        routingLogger.error("Navigation failed: No route registered for route '\(route.name)' (hashId: \(route.hashId))")
        return EmptyView()
      }
    }
    return builder.buildErased(route: route, with: self)
  }

  /// Returns the background color for the given route, if specified.
  ///
  /// - Parameters:
  ///   - route: The route to get the background color for.
  ///   - colorScheme: The current color scheme (light or dark).
  /// - Returns: The custom background color, or `nil` to use the default.
  func backgroundColor(for route: any Route, colorScheme: ColorScheme) -> Color? {
    registry[route.hashId]?.backgroundColor?(colorScheme)
  }

  private var registry = [AnyHashable: any RouteBuilder]()

}

// MARK: - Router

/// Manages navigation state and provides methods for programmatic navigation.
///
/// The `Router` maintains a navigation stack using SwiftUI's `@Observable` macro,
/// automatically triggering UI updates when navigation occurs. It must be used
/// with `RoutableNavigationStack` to function properly.
///
/// ## Usage
///
/// Inject the router via SwiftUI's environment:
///
/// ```swift
/// @Environment(Router.self) private var router
///
/// Button("Open Settings") {
///   router.navigate(to: SettingsRoute())
/// }
/// ```
///
/// ## Navigation Methods
///
/// - `navigate(to:)`: Push a registered route onto the stack
/// - `push(_:)`: Push any view without defining a route (creates anonymous route)
/// - `pop()`: Remove the top route from the stack
/// - `popToRoot()`: Clear the entire navigation stack
/// - `embed(route:)`: Embed a route's view without navigation
@MainActor @Observable
public final class Router {

  /// Creates a new router with the given route registry.
  ///
  /// - Parameter registry: The registry containing all route builders.
  public init(registry: RoutesRegistry) {
    self.registry = registry
  }

  /// Navigates to a registered route by pushing it onto the navigation stack.
  ///
  /// The route must have a corresponding `RouteBuilder` registered in the registry.
  /// If the route is not registered, an error is logged and an empty view is shown.
  ///
  /// - Parameter destination: The route to navigate to.
  ///
  /// ## Example
  ///
  /// ```swift
  /// router.navigate(to: SettingsRoute())
  /// ```
  public func navigate(to destination: any Route) {
    path.append(AnyRoute(destination))
  }

  /// Removes the topmost route from the navigation stack.
  ///
  /// If the stack is empty, this method does nothing. This is safe to call
  /// at any time without checking the stack state.
  ///
  /// ## Example
  ///
  /// ```swift
  /// Button("Back") {
  ///   router.pop()
  /// }
  /// ```
  public func pop() {
    if !path.isEmpty {
      path.removeLast()
    }
  }

  /// Removes all routes from the navigation stack, returning to the root view.
  ///
  /// ## Example
  ///
  /// ```swift
  /// Button("Go Home") {
  ///   router.popToRoot()
  /// }
  /// ```
  public func popToRoot() {
    path.removeAll()
  }

  /// Embeds a route's view without performing navigation.
  ///
  /// This is useful for embedding route-managed views within other views
  /// without adding them to the navigation stack.
  ///
  /// - Parameter route: The route whose view should be embedded.
  /// - Returns: The view constructed by the route's builder.
  ///
  /// ## Example
  ///
  /// ```swift
  /// var body: some View {
  ///   VStack {
  ///     router.embed(route: HeaderRoute())
  ///     // Other content...
  ///   }
  /// }
  /// ```
  public func embed(route: any Route) -> any View {
    registry.view(for: route)
  }

  /// Pushes any view onto the navigation stack without defining a route.
  ///
  /// This creates an "anonymous route" internally, allowing ad-hoc navigation
  /// without the ceremony of defining `Route` and `RouteBuilder` types.
  /// Useful for one-off navigation or prototyping.
  ///
  /// - Parameter view: The view to push onto the stack.
  ///
  /// ## Example
  ///
  /// ```swift
  /// Button("Show Detail") {
  ///   router.push(DetailView(item: item))
  /// }
  /// ```
  public func push(_ view: any View) {
    let route = AnonymousRoute(id: path.count)
    let builder = AnonymousRouteBuilder(id: route.id, view: view)
    registry.register(routeBuilder: builder)

    navigate(to: route)
  }

  /// The navigation path stack.
  ///
  /// This property is observed by SwiftUI's navigation system and should not be
  /// modified directly. Use the navigation methods instead.
  var path = [AnyRoute]()

  /// The routes registry used for view construction.
  let registry: RoutesRegistry

}
