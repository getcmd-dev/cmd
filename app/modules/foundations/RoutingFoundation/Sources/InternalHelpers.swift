// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import os
@preconcurrency import SwiftUI

extension Route {
  /// Converts the route's ID into an `AnyHashable` for use as a dictionary key.
  var hashId: AnyHashable { .init(id) }
}

// MARK: - AnyRoute

/// Type-erased wrapper for `Route` instances, enabling heterogeneous route storage.
///
/// SwiftUI's `NavigationStack` requires a homogeneous path type, but the routing system
/// needs to support multiple route types in the same stack. `AnyRoute` solves this by
/// erasing the specific `Route` type while preserving identity and equality semantics.
struct AnyRoute: Route {

  /// Creates a type-erased route wrapper.
  ///
  /// - Parameter route: The route to wrap. If already an `AnyRoute`, returns it directly
  ///   to prevent double-wrapping.
  init<R: Route>(_ route: R) {
    // Prevent double-wrapping if the route is already an AnyRoute
    if let anyRoute = route as? AnyRoute {
      self = anyRoute
      return
    }
    wrappedValue = route

    _equal = { otherRoute in
      if let otherRoute = otherRoute.wrappedValue as? R {
        return route == otherRoute
      }
      return false
    }
    _hash = { hasher in
      route.hash(into: &hasher)
    }
  }

  /// The original wrapped route value.
  let wrappedValue: any Route

  var id: AnyHashable { .init(wrappedValue.id) }

  var name: String { wrappedValue.name }

  /// Compares two type-erased routes for equality.
  ///
  /// Routes are equal if they have the same type and the same hash value.
  /// This ensures that routes of different types are never considered equal,
  /// even if they have the same ID value.
  static func ==(lhs: AnyRoute, rhs: AnyRoute) -> Bool {
    lhs._equal(rhs)
  }

  /// Hashes the type-erased route.
  ///
  /// Uses the cached hash value for performance, avoiding repeated hashing
  /// of the existential type.
  func hash(into hasher: inout Hasher) {
    _hash(&hasher)
  }

  private let _equal: @Sendable (AnyRoute) -> Bool
  private let _hash: @Sendable (inout Hasher) -> Void

}

let routingLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cmd.app", category: "RoutingFoundation")

extension RouteBuilder {

  /// Converts the builder's route ID to `AnyHashable` for use as a dictionary key.
  var id: AnyHashable { .init(routeId) }

  /// Builds a view for the given route, handling type erasure and errors.
  ///
  /// This method unwraps `AnyRoute` instances, validates type correctness, and handles
  /// any errors thrown during view construction.
  ///
  /// - Parameters:
  ///   - route: The route to build a view for (may be type-erased).
  ///   - registry: The routes registry.
  /// - Returns: The constructed view, or `EmptyView()` if an error occurs.
  ///
  /// ## Error Handling
  ///
  /// - **Type Mismatch**: Logs error and returns `EmptyView()`
  /// - **Build Error**: Logs error details and returns `EmptyView()`
  @MainActor
  func buildErased(route: any RoutingFoundation.Route, with registry: RoutesRegistry) -> any View {
    var route = route
    // Unwrap AnyRoute to get the actual route instance
    if let anyRoute = route as? AnyRoute {
      route = anyRoute.wrappedValue
    }

    // Validate the route type matches this builder's expected type
    guard let typedRoute = route as? Route else {
      routingLogger.error(
        "Route type mismatch: expected \(Route.self), got \(type(of: route)) for route '\(route.name)'")
      return EmptyView()
    }

    // Attempt to build the view, catching any errors
    do {
      return try build(route: typedRoute, with: registry)
    } catch {
      routingLogger.error("Builder failed for route '\(route.name)': \(error.localizedDescription)")
      return EmptyView()
    }
  }
}

// MARK: - AnonymousRoute

/// Internal route type for ad-hoc navigation via `Router.push(_:)`.
struct AnonymousRoute: Route {

  var name: String { "AnonymousRoute-\(id)" }

  var id: Int
}

// MARK: - AnonymousRouteBuilder

/// Builder for anonymous routes created via `Router.push(_:)`.
///
/// Unlike standard builders, this stores a pre-built view rather than constructing
/// it dynamically. This is because anonymous routes are created with a specific view
/// instance already provided.
struct AnonymousRouteBuilder: RouteBuilder {
  var routeId: Int { id }

  let id: Int

  /// The pre-built view to display for this anonymous route.
  let view: any View

  func build(route _: AnonymousRoute, with _: RoutesRegistry) throws -> any View {
    view
  }
}
