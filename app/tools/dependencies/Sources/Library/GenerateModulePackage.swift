// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftFormat
import SwiftParser
import SwiftSyntax

// MARK: - GenerateModulePackage

/// Generate the Package.swift file for one module, for instance at ./repo/ModuleA/Package.swift
public final class GenerateModulePackage {

  public init(
    moduleDir: URL,
    allTargets: [String: TargetInfo],
    templatePackageSource: SourceFileSyntax,
    templatePackageURL: URL)
    throws
  {
    self.moduleDir = moduleDir.canonicalURL
    self.allTargets = allTargets
    self.templatePackageSource = templatePackageSource
    self.templatePackageURL = templatePackageURL
  }

  public func run() throws {
    let targets = allTargets
    let focussedTargets = targets.values.filter { $0.moduleDir == moduleDir }

    var selectedTargets = focussedTargets.reduce(into: [String: TargetInfo]()) { result, target in
      result[target.name] = target
    }
    var externalDependencies = Set<String>()

    // Add all dependencies, not including transitives.
    for target in focussedTargets {
      let targetDependencies = targets.values.filter { $0.name == target.name }

      for dependency in targetDependencies.flatMap(\.dependencies) {
        if selectedTargets[dependency.name] != nil {
          // Dependency already added
          continue
        }
        guard let dependencyTarget = targets[dependency.name] else {
          fatalError("Target \(dependency.name) not found")
        }
        selectedTargets[dependency.name] = dependencyTarget
      }

      for dependency in targetDependencies.flatMap(\.externalDependencies) {
        externalDependencies.insert(dependency.packageName)
      }
    }

    // Filter for targets with XSources/ folders (nameInModule starts with "X" and type is Sources)
    let productTargetNames = focussedTargets
      .filter { target in
        return target.type == .Sources
      }
      .map(\.name)

    let packageURL = moduleDir.appendingPathComponent("Package.swift")
    var rewrittenFile = templatePackageSource

    rewrittenFile = UpdateRelativePathInPackage(packageURL: templatePackageURL, targetURL: packageURL)
      .visit(rewrittenFile)
    rewrittenFile = try AddTargetToPackage(
      source: rewrittenFile,
      packageDirURL: moduleDir,
      modules: [moduleDir.path]).rewrite()

    rewrittenFile = UpdatePackage(
      packageURL: packageURL,
      name: moduleDir.lastPathComponent,
      focussedTargetNames: focussedTargets.map(\.name),
      productTargetNames: productTargetNames,
      internalDependencies: selectedTargets.values.filter { $0.moduleDir != moduleDir },
      externalDependencies: externalDependencies)
      .visit(rewrittenFile)

    // Format the output with swift-format for consistent indentation
    var configuration = Configuration()
    configuration.indentation = .spaces(2)
    configuration.lineLength = 120

    let unformattedCode = rewrittenFile.description
    var formattedOutput = ""
    try SwiftFormatter(configuration: configuration).format(
      source: unformattedCode,
      assumingFileURL: packageURL,
      selection: Selection(offsetRanges: []),
      to: &formattedOutput)

    try fileManager.write(
      """
      // This file is generated. Do not modify directly.

      \(formattedOutput)
      """,
      to: packageURL,
      atomically: true,
      encoding: .utf8)
  }

  let moduleDir: URL
  let allTargets: [String: TargetInfo]
  let templatePackageSource: SourceFileSyntax
  let templatePackageURL: URL

}

// MARK: - UpdatePackage

final class UpdatePackage: SyntaxRewriter {

  init(
    packageURL: URL,
    name: String,
    focussedTargetNames: [String],
    productTargetNames: [String],
    internalDependencies: [TargetInfo],
    externalDependencies: Set<String>)
  {
    self.packageURL = packageURL
    self.name = name
    self.focussedTargetNames = focussedTargetNames
    self.productTargetNames = productTargetNames
    self.externalDependencies = externalDependencies
    self.internalDependencies = internalDependencies
  }

  let focussedTargetNames: [String]
  let productTargetNames: [String]
  let externalDependencies: Set<String>
  let internalDependencies: [TargetInfo]
  let packageURL: URL
  let name: String

  override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
    guard
      node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package"
    else {
      return super.visit(node)
    }

    guard
      let nameArgumentIdx = node.arguments.firstIndex(where: { $0.label?.text == "name" }),
      let productsArgumentIdx = node.arguments.firstIndex(where: { $0.label?.text == "products" }),
      let dependenciesArgumentIdx = node.arguments.firstIndex(where: { $0.label?.text == "dependencies" })
    else {
      fatalError("missing products or dependencies argument in Package")
    }
    var arguments = node.arguments
    var newNameArg = LabeledExprSyntax(label: "name", expression: makeExpr("\"\(name)\""))
    newNameArg.trailingComma = .commaToken()
    arguments.remove(at: nameArgumentIdx)
    arguments.insert(newNameArg, at: nameArgumentIdx)

    let newProducts = makeExpr("""
      [
        \(productTargetNames.sorted().map { ".library(name: \"\($0)\", targets: [\"\($0)\"])" }.joined(separator: ",\n"))
      ]
      """)
    var newProductArg = LabeledExprSyntax(label: "products", expression: newProducts)
    newProductArg.trailingComma = .commaToken()
    arguments.remove(at: productsArgumentIdx)
    arguments.insert(newProductArg, at: productsArgumentIdx)

    if let dependencies = arguments[dependenciesArgumentIdx].expression.as(ArrayExprSyntax.self) {
      arguments[dependenciesArgumentIdx] = arguments[dependenciesArgumentIdx].with(
        \.expression,
        ExprSyntax(dependencies.with(
          \.elements,
          dependencies.elements
            .filter { dep in !externalDependencies.filter { dep.description.contains("/\($0)") }.isEmpty }
            .appending(
              contentOf: internalDependencies
                .sorted(using: KeyPathComparator(\.name))
                .compactMap { dep -> ArrayElementSyntax? in
                  return ArrayElementSyntax(
                    leadingTrivia: .newline,
                    expression: makeExpr(
                      ".package(path: \"\(dep.moduleDir.pathRelative(to: packageURL.deletingLastPathComponent()))\"),"),
                    trailingComma: .commaToken())
                }))))
    }

    return ExprSyntax(super.visit(node.with(\.arguments, arguments)))
  }
}

// MARK: - UpdateRelativePathInPackage

/// Update relative path from the original package source to match their new location in the target package.
final class UpdateRelativePathInPackage: SyntaxRewriter {

  init(
    packageURL: URL,
    targetURL: URL)
  {
    self.packageURL = packageURL
    self.targetURL = targetURL
  }

  let packageURL: URL
  let targetURL: URL

  override func visit(_ node: LabeledExprSyntax) -> LabeledExprSyntax {
    guard node.label?.text.description == "path" else {
      return super.visit(node)
    }
    guard
      let segments = node.expression.as(StringLiteralExprSyntax.self)?.segments,
      segments.count == 1, let path = segments.first?.trimmedDescription
    else {
      return super.visit(node)
    }
    guard path.starts(with: ".") else {
      return super.visit(node)
    }
    let absolutePath = packageURL.deletingLastPathComponent().appending(path: path).canonicalURL
    let newRelativePath = absolutePath.pathRelative(to: targetURL.deletingLastPathComponent())

    // Preserve the original trivia (spacing) from the node
    let newExpression = makeExpr("\"\(newRelativePath)\"")
    return node.with(\.expression, ExprSyntax(newExpression))
  }
}
