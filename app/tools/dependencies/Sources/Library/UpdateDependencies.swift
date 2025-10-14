// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - UpdateDependencies

/// A Swift syntax rewriter that analyzes and updates package dependencies in Package.swift files.
/// It compares actual imports used in source files against declared dependencies and updates
/// the package manifest accordingly by:
/// - Adding missing dependencies that are imported but not declared
/// - Removing unused dependencies that are declared but not imported
public enum UpdateDependencies {

  /// Update all dependencies:
  ///   - update Module.swift files (initialize empty files, fix names, add properties)
  ///   - add / remove dependencies in the `Module.swift files`
  ///   - generate the aggregated `Package.swift` file
  ///   - generate `Package.swift` for each module
  ///
  ///   - Parameters:
  ///   - packagePath: The path to the root package directory.
  ///   - all: If true, also generate `Package.swift` files for each module.
  public static func update(packageURL: URL, all: Bool = false) throws -> [String: TargetInfo] {
    let templatePackageURL = packageURL.deletingLastPathComponent()
      .appending(path: "Package.template.swift")
    let templatePackageSource = try Parser.parse(source: fileManager.read(contentsOfFile: templatePackageURL.path))

    // First, discover all existing Module.swift, and the targets the define:
    let repoURL = templatePackageURL.deletingLastPathComponent()
    let moduleFiles = try fileManager.files(at: repoURL, includingPropertiesForKeys: nil)?
      .filter { $0.lastPathComponent == "Module.swift" }
      .map { file -> (URL, SourceFileSyntax) in
        let content = try fileManager.read(contentsOfFile: file.path)
        let source = Parser.parse(source: content)
        return (file, source)
      }
      .sorted(by: { $0.0.path < $1.0.path }) ?? []

    var targets = try moduleFiles
      .flatMap { moduleFile in
        let moduleDir = moduleFile.0.deletingLastPathComponent()
        return try fileManager.contentsOfDirectory(at: moduleDir)
          .filter { directoryIsNotEmpty($0) }
          .compactMap {
            TargetInfo(folderURL: $0, moduleDir: moduleDir, source: moduleFile.1)
          }
      }
      .reduce(into: [String: TargetInfo]()) { result, target in
        result[target.name] = target
      }
    let externalDependencies = targets.values.reduce(into: [String: TargetInfo.ExternalDependency](), { result, target in
      for externalDependency in target.externalDependencies { result[externalDependency.name] = externalDependency }
    })

    // Then identify existing dependencies based on imports
    targets = try targets.mapValues { target in
      var target = target
      let imports = try collectAllImports(in: target.folderURL)
      target.dependencies = imports
        .compactMap { targets[$0] }
        .sorted(using: KeyPathComparator(\.name))
      target.externalDependencies = imports
        .compactMap { externalDependencies[$0] }
        .sorted(using: KeyPathComparator(\.name))

      return target
    }

    // Then rewrite the Module.swift files
    let targetsByModuleDir = targets.reduce(into: Dictionary(uniqueKeysWithValues: moduleFiles.map { (
      $0.0.deletingLastPathComponent(),
      []) }))
    { result, target in
      result[target.value.moduleDir, default: []].append(target.value)
    }
    try targetsByModuleDir.forEach { moduleDir, targets in
      try UpdateModuleFile(moduleFileURL: moduleDir.appending(path: "Module.swift"), targets: targets).run()
    }

    // Then, update the main Package.swift
    let packageModifier = GenerateEntirePackage(
      templatePackageSource: templatePackageSource,
      packageDirURL: templatePackageURL.deletingLastPathComponent())
    try packageModifier.run()

    guard all else { return targets }
    // Finally, if requested, generate all local Package.swift

    for moduleDir in targetsByModuleDir.keys
      .sorted(using: KeyPathComparator(\.path))
    {
      try GenerateModulePackage(
        moduleDir: moduleDir,
        allTargets: targets,
        templatePackageSource: templatePackageSource,
        templatePackageURL: templatePackageURL).run()
    }
    return targets
  }

  /// Collects all the unique imports found in `.swift` files under `directoryPath`.
  /// - Parameter directoryPath: The file system path to search (recursively).
  /// - Returns: A set of strings, e.g. { "SwiftUI", "Foundation.NSString", ... }.
  private static func collectAllImports(in directoryURL: URL) throws -> Set<String> {
    var allImports = Set<String>()

    // Recursively gather *.swift files from the directory.
    let fileURLs = allSwiftFiles(in: directoryURL)

    for fileURL in fileURLs {
      if let fileText = try? fileManager.read(contentsOfFile: fileURL.path) {
        let sourceFile = Parser.parse(source: fileText)
        let imports = findImports(in: sourceFile)
        allImports.formUnion(imports)
      }
    }

    return allImports
  }

  /// Recursively traverses `baseURL` to find every file ending in `.swift`.
  private static func allSwiftFiles(in baseURL: URL) -> [URL] {
    var result = [URL]()
    if
      let enumerator = fileManager.files(
        at: baseURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles])
    {
      for file in enumerator {
        if file.pathExtension == "swift" {
          result.append(file)
        }
      }
    }
    return result
  }

  /// Finds all the import statements in a parsed Swift file and returns their module paths.
  /// For example:
  ///    import SwiftUI           → "SwiftUI"
  ///    import Foundation.NSData → "Foundation"
  private static func findImports(in sourceFile: SourceFileSyntax) -> [String] {
    var imports = [String]()
    for statement in sourceFile.statements {
      if let importDecl = statement.item.as(ImportDeclSyntax.self) {
        let pathComponents = importDecl.path.map(\.name.text)
        let pathString = pathComponents.first ?? ""
        imports.append(pathString)
      }
    }
    return imports
  }

}

// MARK: - DependencyInfo

public struct DependencyInfo {
  /// The original syntax expression (e.g. `"SomeTarget"` or `product(name: "KeyboardShortcuts", package: "...")`)
  let raw: ExprSyntax

  /// The normalized dependency name (e.g. "SomeTarget" or "KeyboardShortcuts")
  public let name: String

  public let package: PackageDependencyInfo?

  public struct PackageDependencyInfo {
    public let packageName: String
    public let procuct: String
  }
}

extension ExprSyntax {
  var dependencyInfo: DependencyInfo? {
    // If it's a simple string literal:
    if
      let stringLit = self.as(StringLiteralExprSyntax.self),
      let segment = stringLit.segments.first?.as(StringSegmentSyntax.self)
    {
      let rawValue = segment.content.text
      return DependencyInfo(raw: self, name: rawValue, package: nil)
    }
    // If it's .product(name: "...", package: "...")
    else if
      let call = self.as(FunctionCallExprSyntax.self),
      let base = call.calledExpression.as(MemberAccessExprSyntax.self),
      base.declName.baseName.text == "product",
      let name = findStringArgument(in: call.arguments, label: "name") ?? findStringArgument(in: call.arguments, label: "package")
    {
      var package: DependencyInfo.PackageDependencyInfo?
      if let packageName = findStringArgument(in: call.arguments, label: "package") {
        let product = findStringArgument(in: call.arguments, label: "name") ?? packageName
        package = DependencyInfo.PackageDependencyInfo(packageName: packageName, procuct: product)
      }
      return DependencyInfo(
        raw: self,
        name: name,
        package: package)
    }
    return nil
  }
}

extension DependencyInfo {
  var sortingId: String {
    "\(package != nil ? "0" : "1")\(name.lowercased())"
  }
}
