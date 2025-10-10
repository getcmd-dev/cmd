// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Observation
@preconcurrency import SwiftUI

// MARK: - Route

public protocol Route: Sendable, Hashable {
  associatedtype RouteID: Hashable
  var id: RouteID { get }
  var name: String { get }
}

// MARK: - RouteBuilder

public protocol RouteBuilder: Sendable {
  associatedtype Route: RoutingFoundation.Route

  var routeId: Route.RouteID { get }

  var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? { get }

  @MainActor
  func build(route: Route, with registry: RoutesRegistry) throws -> any View
}

extension RouteBuilder {
  public var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? { nil }
}

// MARK: - RoutesRegistry

@MainActor
public final class RoutesRegistry: Sendable {

  public init() { }

  public func register(routeBuilder: any RouteBuilder) {
    registry[routeBuilder.id] = routeBuilder
  }

  public func register(subrouteBuilder: any RouteBuilder) {
    // Todo: scope this to the current path.
    registry[subrouteBuilder.id] = subrouteBuilder
  }

  func view(for route: any Route) -> any View {
    guard let builder = registry[route.hashId] else {
      if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        // Swift UI is running, the route might not have been registered, this is fine.
        return Text("Missing route: \(route.name)")
      } else {
        assertionFailure("No route registered for route `\(route.name)`")
        return EmptyView()
      }
    }
    return builder.buildErased(route: route, with: self)
  }

  func backgroundColor(for route: any Route, colorScheme: ColorScheme) -> Color? {
    registry[route.name]?.backgroundColor?(colorScheme)
  }

  private var registry = [AnyHashable: any RouteBuilder]()

}

// MARK: - Router

@MainActor @Observable
public final class Router {
  public init(registry: RoutesRegistry) {
    self.registry = registry
  }

  public func navigate(to destination: any Route) {
    path.append(AnyRoute(destination))
  }

  public func pop() {
    if !path.isEmpty {
      path.removeLast()
    }
  }

  public func popToRoot() {
    path.removeAll()
  }

  public func embed(route: any Route) -> any View {
    registry.view(for: route)
  }

  public func push(_ view: any View) {
    let route = AnonymousRoute(id: path.count)
    let builder = AnonymousRouteBuilder(id: route.id, view: view)
    registry.register(routeBuilder: builder)

    navigate(to: route)
  }

  var path = [AnyRoute]()

  let registry: RoutesRegistry

}
