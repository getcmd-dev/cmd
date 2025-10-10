// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import SwiftUI

extension Route {
  var hashId: AnyHashable { .init(id) }
}

// MARK: - AnyRoute

struct AnyRoute: Route {
  public init<R: Route>(_ route: R) {
    if let anyRoute = route as? AnyRoute {
      self = anyRoute
      return
    }
    wrappedValue = route
    typeID = ObjectIdentifier(R.self)
    storedHash = route.hashValue
  }

  public var id: AnyHashable { .init(wrappedValue.id) }

  public var name: String { wrappedValue.name }

  public static func ==(lhs: AnyRoute, rhs: AnyRoute) -> Bool {
    lhs.typeID == rhs.typeID && lhs.storedHash == rhs.storedHash
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(typeID)
    hasher.combine(storedHash)
  }

  let wrappedValue: any Route

  private let typeID: ObjectIdentifier
  private let storedHash: Int
}

extension RouteBuilder {

  var id: AnyHashable { .init(routeId) }

  @MainActor
  func buildErased(route: any RoutingFoundation.Route, with registry: RoutesRegistry) -> any View {
    var route = route
    if let anyRoute = route as? AnyRoute {
      route = anyRoute.wrappedValue
    }
    guard let typedRoute = route as? Route else {
      assertionFailure("Route type mismatch: expected \(Route.self), got \(type(of: route))")
      return EmptyView()
    }

    do {
      return try build(route: typedRoute, with: registry)
    } catch {
      assertionFailure("Builder threw error: \(error)")
      return EmptyView()
    }
  }
}

// MARK: - AnonymousRoute

struct AnonymousRoute: Route {

  var name: String { "AnonymousRoute-\(id)" }

  var id: Int
}

// MARK: - AnonymousRouteBuilder

struct AnonymousRouteBuilder: RouteBuilder {
  var routeId: Int { id }

  let id: Int

  let view: any View

  func build(route _: AnonymousRoute, with _: RoutesRegistry) throws -> any View {
    view
  }
}
