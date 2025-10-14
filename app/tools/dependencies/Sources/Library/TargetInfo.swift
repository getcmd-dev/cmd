// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftSyntax

/// Represents information about one target
public struct TargetInfo {

  init?(folderURL: URL, moduleDir: URL, source: SourceFileSyntax?) {
    self.folderURL = folderURL
    self.moduleDir = moduleDir
    let folderName = folderURL.lastPathComponent

    guard let type = TargetType.allCases.first(where: { folderName.hasSuffix($0.rawValue) }) else {
      return nil
    }

    // Extract external dependencies
    self.type = type
    nameInModule = String(folderName.dropLast(type.rawValue.count)) // eg: "", or "Interface"
    name =
      "\(moduleDir.lastPathComponent)\(nameInModule)\(type.propertyKey)" // eg: "NetworkingService", or "NetworkingServiceInterface"
    dependencies = [] // Set later
    externalDependencies = []

    if
      let existingDependencies = source?.statements.first?.item.as(FunctionCallExprSyntax.self)?.arguments
        .first(where: { $0.label?.trimmedDescription == dependenciesProperty })?.expression.as(ArrayExprSyntax.self)
    {
      externalDependencies = existingDependencies.elements
        .compactMap { expr in
          if let dep = expr.expression.dependencyInfo, let package = dep.package {
            return ExternalDependency(raw: dep.raw, name: dep.name, packageName: package.packageName, procuct: package.procuct)
          }
          return nil
        }
    }
  }

  public enum TargetType: String, CaseIterable {
    case Sources
    case Tests
    case Macro

    public var propertyKey: String {
      switch self {
      case .Sources: ""
      case .Tests: "Test"
      case .Macro: "Macro"
      }
    }
  }

  public struct ExternalDependency {
    /// The original syntax expression (e.g. `"SomeTarget"` or `product(name: "KeyboardShortcuts", package: "...")`)
    let raw: ExprSyntax

    /// The normalized dependency name (e.g. "SomeTarget" or "KeyboardShortcuts")
    public let name: String

    public let packageName: String
    public let procuct: String
  }

  public let moduleDir: URL
  public let folderURL: URL
  public let type: TargetType
  /// eg: "NetworkingService", or "NetworkingServiceInterface""/
  public let name: String
  /// eg: "", or "Interface"
  public let nameInModule: String

  public var dependencies: [TargetInfo]

  public var externalDependencies: [ExternalDependency]

  public var moduleFileURL: URL {
    moduleDir.appendingPathComponent("Module.swift")
  }

  var dependenciesProperty: String {
    "\(nameInModule)\(type.propertyKey)Dependencies".camelCased
  }

  var excludeProperty: String {
    "\(nameInModule)\(type.propertyKey)Exclude".camelCased
  }

  var resourcesProperty: String {
    "\(nameInModule)\(type.propertyKey)Resources".camelCased
  }

  var allProperties: [String] {
    [dependenciesProperty, excludeProperty, resourcesProperty]
  }

}
