// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder

/// Updates Module.swift files based on folder structure:
/// - Initializes empty Module.swift files
/// - Updates module names to match folder names
/// - Adds/Remove properties based on folder existence (Tests/, Interface/, InterfaceTests/)
public final class UpdateModuleFile {

  init(moduleFileURL: URL, targets: [TargetInfo]) {
    self.moduleFileURL = moduleFileURL.canonicalURL
    self.targets = targets
  }

  public func run() throws {
    try updateModuleFile(at: moduleFileURL, targets: targets)
  }

  private let moduleFileURL: URL
  private let targets: [TargetInfo]

  private func updateModuleFile(at moduleFileURL: URL, targets: [TargetInfo]) throws {
    let moduleDir = moduleFileURL.deletingLastPathComponent()
    let moduleName = moduleDir.lastPathComponent

    // Read the file
    var content = try fileManager.read(contentsOfFile: moduleFileURL.path)
    var sourceFile = Parser.parse(source: content)

    // In the file is empty, initialize it.
    if sourceFile.trimmedDescription.isEmpty {
      content = """
        Target.module(
          name: "\(moduleName)",
          dependencies: [])

        """
      try fileManager.write(content, to: moduleFileURL, atomically: true, encoding: .utf8)
      sourceFile = Parser.parse(source: content)
    }

    guard
      let firstStatement = sourceFile.statements.first,
      let expr = firstStatement.item.as(ExprSyntax.self),
      let functionCall = expr.as(FunctionCallExprSyntax.self)
    else {
      return
    }

    // Update the function call
    let updatedCall = updateModule(
      functionCall,
      moduleName: moduleName,
      targetFolders: targets)

    // Write back
    let newContent = updatedCall.description + "\n"
    if newContent != content {
      try fileManager.write(newContent, to: moduleFileURL, atomically: true, encoding: .utf8)
    }
  }

  private func updateModule(
    _ call: FunctionCallExprSyntax,
    moduleName: String,
    targetFolders: [TargetInfo])
    -> FunctionCallExprSyntax
  {
    // Collect all valid property names from target folders
    let allValidProperties = Set(targetFolders.flatMap { [$0.dependenciesProperty, $0.excludeProperty, $0.resourcesProperty] })

    // Process existing arguments and keep those that are valid
    var argumentsByLabel = [String: LabeledExprSyntax]()

    for arg in call.arguments {
      guard let label = arg.label?.text else { continue }

      var newArg = arg

      if label == "name" {
        // Update name if different
        if
          let currentName = findStringArgument(in: call.arguments, label: "name"),
          currentName != moduleName
        {
          newArg = arg.with(
            \.expression,
            ExprSyntax(StringLiteralExprSyntax(content: moduleName)))
        }
        argumentsByLabel[label] = newArg
      } else if label == "path" {
        // Keep path as-is
        argumentsByLabel[label] = newArg
      } else if allValidProperties.contains(label) {
        // Keep valid target properties
        argumentsByLabel[label] = newArg
      }
      // Invalid properties are silently dropped
    }

    // Set dependencies properties
    for targetFolder in targetFolders {
      let dependencies = targetFolder.externalDependencies.map(\.raw) +
        targetFolder.dependencies.map({ ExprSyntax(StringLiteralExprSyntax(content: $0.name)) })
      argumentsByLabel[targetFolder.dependenciesProperty] = LabeledExprSyntax(
        label: .init(stringLiteral: targetFolder.dependenciesProperty),
        colon: .colonToken(trailingTrivia: .space),
        expression: ExprSyntax(makeArrayExprSyntax(from: dependencies)))
    }

    // Sort arguments
    let sortedArguments = sortArguments(argumentsByLabel, targetFolders: targetFolders)

    // Format arguments with proper trivia and commas
    var formattedArguments = [LabeledExprSyntax]()

    // Get the original first argument's leading trivia to preserve formatting
    let originalFirstArgLeadingTrivia = call.arguments.first?.leadingTrivia ?? (.newline + .spaces(2))

    for (index, arg) in sortedArguments.enumerated() {
      var newArg = arg
      // Strip trailing trivia from expression
      let cleanExpr = newArg.expression.with(\.trailingTrivia, [])
      newArg = newArg.with(\.expression, cleanExpr)

      // Add leading trivia - first argument preserves original, others get newline + indent
      if index == 0 {
        newArg = newArg.with(\.leadingTrivia, originalFirstArgLeadingTrivia)
      } else {
        newArg = newArg.with(\.leadingTrivia, .newline + .spaces(2))
      }

      // Add trailing comma except for last argument
      newArg.trailingComma = index < sortedArguments.count - 1 ? .commaToken() : nil

      formattedArguments.append(newArg)
    }

    return call.with(\.arguments, LabeledExprListSyntax(formattedArguments))
  }

  /// Sorts arguments according to the specified rules:
  /// 1. name, then path
  /// 2. Sorted by target (Sources, then Tests, then Macro, etc.)
  /// 3. Within each target: dependencies, exclude, resources
  private func sortArguments(
    _ argumentsByLabel: [String: LabeledExprSyntax],
    targetFolders: [TargetInfo])
    -> [LabeledExprSyntax]
  {
    var result = [LabeledExprSyntax]()

    // 1. Add name and path first
    if let nameArg = argumentsByLabel["name"] {
      result.append(nameArg)
    }
    if let pathArg = argumentsByLabel["path"] {
      result.append(pathArg)
    }

    // 2. Add target properties in sorted order
    for targetFolder in targetFolders.sorted(by: { a, b in
      if a.nameInModule != b.nameInModule {
        return a.nameInModule < b.nameInModule
      }
      if a.type != b.type {
        return a.type.rawValue < b.type.rawValue
      }
      return a.name < b.name
    }) {
      // Add dependencies, exclude, resources in that order
      if let depArg = argumentsByLabel[targetFolder.dependenciesProperty] {
        result.append(depArg)
      }
      if let excludeArg = argumentsByLabel[targetFolder.excludeProperty] {
        result.append(excludeArg)
      }
      if let resourcesArg = argumentsByLabel[targetFolder.resourcesProperty] {
        result.append(resourcesArg)
      }
    }

    return result
  }
}
