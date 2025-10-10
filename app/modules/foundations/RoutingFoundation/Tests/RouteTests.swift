// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Testing
@testable import RoutingFoundation

// MARK: - MockRoute

struct MockRoute: Route {
  var id: String
  var name: String
}

// MARK: - AnotherMockRoute

struct AnotherMockRoute: Route {
  var id: String
  var name: String
}

// MARK: - MockRouteBuilder

struct MockRouteBuilder: RouteBuilder {
  let routeId: String
  let viewText: String
  var customBackgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? = nil

  var backgroundColor: (@MainActor @Sendable (ColorScheme) -> Color)? {
    customBackgroundColor
  }

  @MainActor
  func build(route _: MockRoute, with _: RoutesRegistry) throws -> any View {
    Text(viewText)
  }
}

// MARK: - ThrowingMockRouteBuilder

struct ThrowingMockRouteBuilder: RouteBuilder {
  let routeId: String

  enum BuildError: Error {
    case intentionalFailure
  }

  @MainActor
  func build(route _: MockRoute, with _: RoutesRegistry) throws -> any View {
    throw BuildError.intentionalFailure
  }
}

// MARK: - RouteProtocolTests

@Suite("Route Protocol Tests")
struct RouteProtocolTests {

  @Test("Routes with same id and name are equal")
  func routeEquality() {
    let route1 = MockRoute(id: "test", name: "Test")
    let route2 = MockRoute(id: "test", name: "Test")

    #expect(route1 == route2)
    #expect(route1.hashValue == route2.hashValue)
  }

  @Test("Routes with different ids are not equal")
  func routeInequality() {
    let route1 = MockRoute(id: "test1", name: "Test 1")
    let route2 = MockRoute(id: "test2", name: "Test 2")

    #expect(route1 != route2)
  }

  @Test("Routes can be used as dictionary keys")
  func routeAsDictionaryKey() {
    let route1 = MockRoute(id: "key1", name: "Route 1")
    let route2 = MockRoute(id: "key2", name: "Route 2")

    var dict = [MockRoute: String]()
    dict[route1] = "value1"
    dict[route2] = "value2"

    #expect(dict[route1] == "value1")
    #expect(dict[route2] == "value2")
  }

  @Test("Route hashId extension works correctly")
  func routeHashId() {
    let route = MockRoute(id: "test-id", name: "Test")
    let hashId = route.hashId

    #expect(hashId.base as? String == "test-id")
  }
}

// MARK: - AnyRouteTests

@Suite("AnyRoute Type Erasure Tests")
struct AnyRouteTests {

  @Test("AnyRoute preserves wrapped route identity")
  func anyRouteIdentity() {
    let route = MockRoute(id: "test", name: "Test")
    let anyRoute = AnyRoute(route)

    #expect(anyRoute.id.base as? String == "test")
    #expect(anyRoute.name == "Test")
  }

  @Test("AnyRoute equality for same route")
  func anyRouteEquality() {
    let route = MockRoute(id: "test", name: "Test")
    let anyRoute1 = AnyRoute(route)
    let anyRoute2 = AnyRoute(route)

    #expect(anyRoute1 == anyRoute2)
    #expect(anyRoute1.hashValue == anyRoute2.hashValue)
  }

  @Test("AnyRoute inequality for different routes")
  func anyRouteInequality() {
    let route1 = MockRoute(id: "test1", name: "Test 1")
    let route2 = MockRoute(id: "test2", name: "Test 2")
    let anyRoute1 = AnyRoute(route1)
    let anyRoute2 = AnyRoute(route2)

    #expect(anyRoute1 != anyRoute2)
  }

  @Test("AnyRoute double wrapping returns same instance")
  func anyRouteDoubleWrapping() {
    let route = MockRoute(id: "test", name: "Test")
    let anyRoute1 = AnyRoute(route)
    let anyRoute2 = AnyRoute(anyRoute1)

    #expect(anyRoute1 == anyRoute2)
  }

  @Test("AnyRoute distinguishes different types with same id")
  func anyRouteDifferentTypesWithSameId() {
    let route1 = MockRoute(id: "same-id", name: "Mock Route")
    let route2 = AnotherMockRoute(id: "same-id", name: "Another Mock Route")
    let anyRoute1 = AnyRoute(route1)
    let anyRoute2 = AnyRoute(route2)

    // Should be different due to typeID check
    #expect(anyRoute1 != anyRoute2)
  }
}

// MARK: - RoutesRegistryTests

@Suite("RoutesRegistry Tests")
@MainActor
struct RoutesRegistryTests {

  @Test("Registry stores and retrieves route builders")
  func registerAndRetrieveBuilder() {
    let sut = RoutesRegistry()
    let builder = MockRouteBuilder(routeId: "test", viewText: "Test View")
    sut.register(routeBuilder: builder)

    let route = MockRoute(id: "test", name: "Test")
    let view = sut.view(for: route)

    // View should be successfully built (not EmptyView)
    #expect(view is Text)
  }

  @Test("Registry stores and retrieves route builders, even if the route is wrapped in AnyRoute")
  func registerAndRetrieveBuilderWithAnyRoute() {
    let sut = RoutesRegistry()
    let builder = MockRouteBuilder(routeId: "test", viewText: "Test View")
    sut.register(routeBuilder: builder)

    let route = MockRoute(id: "test", name: "Test")
    let view = sut.view(for: AnyRoute(route))

    // View should be successfully built (not EmptyView)
    #expect(view is Text)
  }

  @Test("Registry returns EmptyView for unregistered route")
  func unregisteredRoute() {
    let sut = RoutesRegistry()
    let route = MockRoute(id: "unregistered", name: "Unregistered")

    let view = sut.view(for: route)

    // Should return EmptyView for unregistered route
    #expect(view is EmptyView)
  }

  @Test("Registry backgroundColor returns builder's color")
  func backgroundColorFromBuilder() {
    let sut = RoutesRegistry()
    let customColor: @MainActor @Sendable (ColorScheme) -> Color = { _ in .red }
    let builder = MockRouteBuilder(
      routeId: "test",
      viewText: "Test",
      customBackgroundColor: customColor)
    sut.register(routeBuilder: builder)

    let route = MockRoute(id: "test", name: "Test")
    let color = sut.backgroundColor(for: route, colorScheme: .light)

    #expect(color != nil)
  }

  @Test("Registry backgroundColor returns nil for unregistered route")
  func backgroundColorForUnregisteredRoute() {
    let sut = RoutesRegistry()
    let route = MockRoute(id: "unregistered", name: "Unregistered")

    let color = sut.backgroundColor(for: route, colorScheme: .light)

    #expect(color == nil)
  }

  @Test("Registry can register multiple builders")
  func multipleBuilders() {
    let sut = RoutesRegistry()
    let builder1 = MockRouteBuilder(routeId: "route1", viewText: "View 1")
    let builder2 = MockRouteBuilder(routeId: "route2", viewText: "View 2")

    sut.register(routeBuilder: builder1)
    sut.register(routeBuilder: builder2)

    let route1 = MockRoute(id: "route1", name: "Route 1")
    let route2 = MockRoute(id: "route2", name: "Route 2")

    let view1 = sut.view(for: route1)
    let view2 = sut.view(for: route2)

    #expect(view1 is Text)
    #expect(view2 is Text)
  }

  @Test("Registry handles builder errors gracefully")
  func builderError() {
    let sut = RoutesRegistry()
    let builder = ThrowingMockRouteBuilder(routeId: "test")
    sut.register(routeBuilder: builder)

    let route = MockRoute(id: "test", name: "Test")
    let view = sut.view(for: route)

    // Should return EmptyView when builder throws
    #expect(view is EmptyView)
  }
}

// MARK: - RouterTests

@Suite("Router Navigation Tests")
@MainActor
struct RouterTests {

  @Test("Router navigate appends to path")
  func navigateAppendsToPath() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    let route = MockRoute(id: "test", name: "Test Route")

    sut.navigate(to: route)

    #expect(sut.path.count == 1)
    #expect(sut.path.first?.name == "Test Route")
  }

  @Test("Router navigate appends multiple routes")
  func navigateMultiple() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    let route1 = MockRoute(id: "1", name: "Route 1")
    let route2 = MockRoute(id: "2", name: "Route 2")
    let route3 = MockRoute(id: "3", name: "Route 3")

    sut.navigate(to: route1)
    sut.navigate(to: route2)
    sut.navigate(to: route3)

    #expect(sut.path.count == 3)
    #expect(sut.path[0].name == "Route 1")
    #expect(sut.path[1].name == "Route 2")
    #expect(sut.path[2].name == "Route 3")
  }

  @Test("Router pop removes last route")
  func popRemovesLastRoute() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    sut.navigate(to: MockRoute(id: "1", name: "Route 1"))
    sut.navigate(to: MockRoute(id: "2", name: "Route 2"))

    sut.pop()

    #expect(sut.path.count == 1)
    #expect(sut.path.first?.name == "Route 1")
  }

  @Test("Router pop on empty path is safe")
  func popEmptyPathIsSafe() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    #expect(sut.path.isEmpty)

    // Should not crash
    sut.pop()

    #expect(sut.path.isEmpty)
  }

  @Test("Router popToRoot clears all routes")
  func popToRootClearsAllRoutes() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    sut.navigate(to: MockRoute(id: "1", name: "Route 1"))
    sut.navigate(to: MockRoute(id: "2", name: "Route 2"))
    sut.navigate(to: MockRoute(id: "3", name: "Route 3"))

    sut.popToRoot()

    #expect(sut.path.isEmpty)
  }

  @Test("Router embed returns view without navigation")
  func embedReturnsViewWithoutNavigation() {
    let registry = RoutesRegistry()
    let builder = MockRouteBuilder(routeId: "test", viewText: "Embedded")
    registry.register(routeBuilder: builder)
    let sut = Router(registry: registry)
    let route = MockRoute(id: "test", name: "Test")

    let view = sut.embed(route: route)

    #expect(view is Text)
    #expect(sut.path.isEmpty) // Path should not change
  }

  @Test("Router push creates anonymous route")
  func pushCreatesAnonymousRoute() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)
    let testView = Text("Pushed View")

    sut.push(testView)

    #expect(sut.path.count == 1)
    #expect(sut.path.first?.name.contains("AnonymousRoute") == true)
  }

  @Test("Router push with multiple views creates unique routes")
  func pushMultipleViews() {
    let registry = RoutesRegistry()
    let sut = Router(registry: registry)

    sut.push(Text("View 1"))
    sut.push(Text("View 2"))
    sut.push(Text("View 3"))

    #expect(sut.path.count == 3)

    // All routes should have unique names
    let names = sut.path.map(\.name)
    #expect(Set(names).count == 3)
  }
}
