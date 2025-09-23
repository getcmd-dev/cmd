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
public final class UpdateDependencies: SyntaxRewriter {

  convenience init(packagePath: URL, targetsInfo: [TargetInfo]? = nil) throws {
    let path = packagePath.canonicalURL

    // Load the file's text
    let fileContents = try String(contentsOfFile: path.path)

    // Parse to syntax
    let packageSource = Parser.parse(source: fileContents)

    try self.init(packageSource: packageSource, packagePath: path, targetsInfo: targetsInfo)
  }

  public init(packageSource: SourceFileSyntax, packagePath: URL, targetsInfo: [TargetInfo]? = nil) throws {
    self.packageSource = packageSource
    let packageDirPath = packagePath.deletingLastPathComponent()

    if let targetsInfo {
      targets = targetsInfo
      isRewrittingModule = true
    } else {
      let extractor = ExtractModuleInfo(packageDirPath: packageDirPath)
      extractor.walk(packageSource)
      targets = extractor.targetInfo
      isRewrittingModule = false
    }

    localPackages = Set(targets.map(\.name))
  }

  public func rewrite(_ filePath: URL) throws {
    let modifiedSource = visit(packageSource)
    try modifiedSource.description.update(url: filePath, atomically: true, encoding: .utf8)
  }

  public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
    guard
      let base = node.calledExpression.as(MemberAccessExprSyntax.self),
      base.declName.baseName.text == "macro" ||
      base.declName.baseName.text == "target" ||
      base.declName.baseName.text == "testTarget" ||
      base.declName.baseName.text == "macroModule" ||
      base.declName.baseName.text == "module"
    else {
      return super.visit(node)
    }

    guard
      let targetName = findStringArgument(in: node.arguments, label: "name"),
      let target = targets.first(where: { $0.name == targetName })
    else {
      return super.visit(node)
    }

    var updatedNode = fixDependencies(in: node, target: target)
    if target.modulePath != nil, let testTarget = targets.first(where: { $0.name == "\(targetName)Tests" }) {
      updatedNode = fixDependencies(in: updatedNode, target: testTarget)
    }
    return ExprSyntax(super.visit(updatedNode))
  }

  let packageSource: SourceFileSyntax

  private let targets: [TargetInfo]
  private let isRewrittingModule: Bool
  private let localPackages: Set<String>

  private func fixDependencies(in node: FunctionCallExprSyntax, target: TargetInfo) -> FunctionCallExprSyntax {
    do {
      // Gather actual imports used in code
      let usedImports = try collectAllImports(in: target.path)

      // Compare declared vs used
      let declaredDep = target.dependencies.reduce(into: [:]) { $0[$1.name] = $1 }
      let codeImports = usedImports.reduce(into: [String: DependencyInfo]()) { $0[$1] = DependencyInfo(
        raw: ExprSyntax("\"\(raw: $1)\""),
        name: $1,
        package: nil) }

      // Missing: local packages that are imported but not declared:
      let missingDependencies = codeImports
        .filter { !declaredDep.keys.contains($0.key) }
        .filter { localPackages.contains($0.key) }

      // Extra: declared but not imported
      let extraDependencies = declaredDep.filter { dep in
        if target.modulePath != nil, target.type == .testTarget, dep.key == target.name.replacing("Tests", with: "") {
          // The test target dependency on its main target is already included for modules.
          return true
        }
        return !codeImports.keys.contains(dep.key) &&
          // Ignore macros, as they cannot be imported but remain required dependencies.
          !dep.key.hasSuffix("Macro")
      }

      if !isRewrittingModule, let modulePath = target.modulePath {
        // Also fix the module declaration.
        let packagePath = modulePath.appending(path: "Module.swift")
        let moduleFormater = try UpdateDependencies(
          packagePath: packagePath,
          targetsInfo: targets)
        try moduleFormater.rewrite(packagePath)
      }

      let argKey = (target.type == .testTarget && target.modulePath != nil) ? "testDependencies" : "dependencies"
      let newArgs = fixDependenciesArgument(node.arguments, add: missingDependencies, remove: extraDependencies, argKey: argKey)
      return node.with(\.arguments, newArgs)
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  /// Remove / add dependencies as necessary, and keep sorted.
  private func fixDependenciesArgument(
    _ argList: LabeledExprListSyntax,
    add: [String: DependencyInfo],
    remove: [String: DependencyInfo],
    argKey: String = "dependencies")
    -> LabeledExprListSyntax
  {
    var newArgList = argList

    if let depIndex = argList.firstIndex(where: { $0.label?.text == argKey }) {
      // Already has a dependencies: [ ... ] param. Modify it:
      let oldArg = argList[depIndex]
      if let oldArrayExpr = oldArg.expression.as(ArrayExprSyntax.self) {
        var dependencies = oldArrayExpr.elements.compactMap(\.expression.dependencyInfo)
        dependencies = dependencies.filter { !remove.keys.contains($0.name) }
        dependencies.append(contentsOf: add.values)
        dependencies.uniqueSort(by: \.sortingId)
        // Build a new array expr
        let newArrayExpr = makeArrayExprSyntax(from: dependencies.map(\.raw))
        let newArg = oldArg.with(\.expression, ExprSyntax(newArrayExpr))
        newArgList = newArgList.with(\.[depIndex], newArg)
      }
    } else {
      // No dependencies param. Create one from scratch containing `add` items.
      let dependencies = Array(add.values).uniqueSorted(by: \.sortingId)
      let newArrayExpr = makeArrayExprSyntax(from: dependencies.map(\.raw))

      // Create a new labeled argument
      let labelToken = TokenSyntax.identifier(argKey)
      let colonToken = TokenSyntax.colonToken()
      let trailingComma = TokenSyntax.commaToken(trailingTrivia: .newline)

      let newArg = LabeledExprSyntax(
        label: labelToken,
        colon: colonToken,
        expression: ExprSyntax(newArrayExpr),
        trailingComma: trailingComma)
      newArgList.append(newArg)
    }

    return newArgList
  }

  // MARK: - Collecting Imports

  /// Collects all the unique imports found in `.swift` files under `directoryPath`.
  /// - Parameter directoryPath: The file system path to search (recursively).
  /// - Returns: A set of strings, e.g. { "SwiftUI", "Foundation.NSString", ... }.
  private func collectAllImports(in directoryPath: String) throws -> Set<String> {
    let directoryURL = URL(fileURLWithPath: directoryPath)
    var allImports = Set<String>()

    // Recursively gather *.swift files from the directory.
    let fileURLs = allSwiftFiles(in: directoryURL)

    for fileURL in fileURLs {
      if let fileText = try? String(contentsOfFile: fileURL.path) {
        let sourceFile = Parser.parse(source: fileText)
        let imports = findImports(in: sourceFile)
        allImports.formUnion(imports)
      }
    }

    return allImports
  }

  /// Recursively traverses `baseURL` to find every file ending in `.swift`.
  private func allSwiftFiles(in baseURL: URL) -> [URL] {
    var result: [URL] = []
    if
      let enumerator = FileManager.default.enumerator(
        at: baseURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles])
    {
      for case let file as URL in enumerator {
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
  private func findImports(in sourceFile: SourceFileSyntax) -> [String] {
    var imports: [String] = []
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

extension UpdateDependencies {
  /// Update all dependencies:
  ///   - add / remove dependencies in the `Module.swift files`
  ///   - generate the aggregated `Package.swift` file
  ///   - generate `Package.swift` for each module
  ///
  ///   - Parameters:
  ///   - packagePath: The path to the root package directory.
  ///   - all: If true, also generate `Package.swift` files for each module.
  public static func update(packagePath: URL, all: Bool = false) throws -> [String: TargetInfo] {
    let basePackagePath = packagePath.deletingLastPathComponent()
      .appending(path: "Package.base.swift")
    let basePackageSource = try Parser.parse(source: String(contentsOf: basePackagePath, encoding: .utf8))

    // Generate the main package
    var mainPackageSource = try GenerateEntirePackage(
      basePackageSource: basePackageSource,
      packageDirPath: basePackagePath.deletingLastPathComponent()).generate()

    // Update dependencies
    try UpdateDependencies(packageSource: mainPackageSource, packagePath: packagePath).rewrite(packagePath)

    // Regenerate the main package
    mainPackageSource = try GenerateEntirePackage(
      basePackageSource: basePackageSource,
      packageDirPath: basePackagePath.deletingLastPathComponent()).generate()

    // Generate all the derived Package.swift for each module
    let targetExtractor = ExtractModuleInfo(packageDirPath: basePackagePath.deletingLastPathComponent())
    targetExtractor.walk(mainPackageSource)
    let allTargets = targetExtractor.targetInfo
      .reduce(into: [String: TargetInfo]()) { acc, target in acc[target.name] = target }

    guard all else { return allTargets }

    for modulePath in allTargets.values
      .compactMap({ $0.modulePath?.path })
      .uniqueSorted(by: \.self)
    {
      try GenerateModulePackage(
        modulePath: modulePath,
        allTargets: allTargets,
        basePackageSource: basePackageSource,
        basePackagePath: basePackagePath).run()
    }
    return allTargets
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
