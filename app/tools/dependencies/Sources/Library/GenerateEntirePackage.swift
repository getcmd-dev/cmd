// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftFormat
import SwiftParser
import SwiftSyntax

// MARK: - GenerateEntirePackage

/// Generate the root Package.swift file, for instance at ./repo/Package.swift
public final class GenerateEntirePackage {

  public init(packageDirPath: String) throws {
    packageDirURL = URL(filePath: packageDirPath).canonicalURL
    templatePackageSource = try Parser.parse(source: fileManager.read(contentsOfFile: packageDirPath))
  }

  public init(templatePackageSource: SourceFileSyntax, packageDirURL: URL) {
    self.packageDirURL = packageDirURL.canonicalURL
    self.templatePackageSource = templatePackageSource
  }

  public func generate() throws -> SourceFileSyntax {
    let directoryPath = packageDirURL.path
    let modules = Self.findModuleFiles(in: directoryPath)

    let rewriter = try AddTargetToPackage(
      source: templatePackageSource,
      packageDirURL: packageDirURL,
      modules: modules)

    return rewriter.rewrite()
  }

  let packageDirURL: URL
  let templatePackageSource: SourceFileSyntax

  func generateSource() throws -> String {
    let rewrittenFile = try generate()

    // Format the output with swift-format for consistent indentation
    var configuration = Configuration()
    configuration.indentation = .spaces(2)
    configuration.lineLength = 120

    let unformattedCode = rewrittenFile.description
    var formattedOutput = ""
    try SwiftFormatter(configuration: configuration).format(
      source: unformattedCode,
      assumingFileURL: nil,
      selection: Selection(offsetRanges: []),
      to: &formattedOutput)

    return """
      // This file is generated. Do not modify directly.

      \(formattedOutput)
      """
  }

  func run() throws {
    try generateSource().update(
      url: packageDirURL.appending(path: "/Package.swift"),
      atomically: true,
      encoding: .utf8)
  }

  private static func findModuleFiles(in directoryPath: String) -> [String] {
    var moduleFiles = [String]()

    func searchDirectory(_ path: String) {
      let directoryURL = URL(fileURLWithPath: path)
      guard let enumerator = fileManager.files(at: directoryURL, includingPropertiesForKeys: nil) else {
        return
      }

      for fileURL in enumerator {
        if fileURL.lastPathComponent == "Module.swift" {
          moduleFiles.append(fileURL.deletingLastPathComponent().path)
        }
      }
    }

    searchDirectory(directoryPath)
    // Sort by module directory name for consistent ordering
    return moduleFiles.sorted { path1, path2 in
      let name1 = URL(fileURLWithPath: path1).lastPathComponent
      let name2 = URL(fileURLWithPath: path2).lastPathComponent
      return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
    }
  }
}

// MARK: - AddTargetToPackage

final class AddTargetToPackage {

  init(source: SourceFileSyntax, packageDirURL: URL, modules: [String]) throws {
    self.packageDirURL = packageDirURL
    packageFile = source

    let packageDir = packageDirURL.path
    moduleExpressions = try modules.map { modulePath in
      let content = try fileManager.read(contentsOfFile: "\(modulePath)/Module.swift")
      let sf = Parser.parse(source: content)

      guard
        let firstItem = sf.statements.first,
        let expr = firstItem.item.as(ExprSyntax.self)
      else {
        throw NSError(
          domain: "AddTargetToPackage",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid module file at \(modulePath)."])
      }

      return rewriteModuleExpression(expr, modulePath: modulePath, packageDir: packageDir)
    }
  }

  func rewrite() -> SourceFileSyntax {
    var newStatements = [CodeBlockItemSyntax]()

    for item in packageFile.statements {
      guard
        let varDecl = item.item.as(VariableDeclSyntax.self),
        isTargetsDeclaration(varDecl)
      else {
        newStatements.append(item)
        continue
      }

      newStatements.append(item)

      for modExpr in moduleExpressions {
        let appendStatement = createAppendStatement(modExpr)
        newStatements.append(appendStatement)
      }
    }

    let blockList = CodeBlockItemListSyntax(newStatements)
    return packageFile.with(\.statements, blockList)
  }

  private let packageDirURL: URL
  private let packageFile: SourceFileSyntax
  private let moduleExpressions: [ExprSyntax]

  private func isTargetsDeclaration(_ decl: VariableDeclSyntax) -> Bool {
    guard decl.bindings.count == 1 else { return false }

    let binding = decl.bindings.first!
    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return false }
    return pattern.identifier.text == "targets"
  }

  private func createAppendStatement(_ modExpr: ExprSyntax) -> CodeBlockItemSyntax {
    let snippet = "\n\ntargets.append(contentsOf: \(modExpr.description))"
    let parsed = Parser.parse(source: snippet)
    guard let statement = parsed.statements.first else {
      fatalError("Could not parse snippet: \(snippet)")
    }
    return statement
  }
}

private func rewriteModuleExpression(
  _ expr: ExprSyntax,
  modulePath: String,
  packageDir: String)
  -> ExprSyntax
{
  guard let call = expr.as(FunctionCallExprSyntax.self) else {
    return expr
  }

  let modulePath = modulePath.replacingOccurrences(of: packageDir, with: ".")

  var hadPath = false
  var newArgs = [LabeledExprSyntax]()

  if let oldArgList = LabeledExprListSyntax(call.arguments) {
    for arg in oldArgList {
      if arg.label?.text == "path" {
        hadPath = true
        // Preserve the original trivia/formatting from the existing path argument
        let newExpr = makeStringLiteralExpr(modulePath)
        let updated = arg.with(\.expression, newExpr)
        newArgs.append(updated)
      } else {
        newArgs.append(arg)
      }
    }
  }

  if !hadPath {
    if var lastArg = newArgs.last {
      lastArg.trailingComma = .commaToken()
      newArgs[newArgs.count - 1] = lastArg
    }
    let pathArg = makePathTupleExpr(modulePath)
    newArgs.append(pathArg)
  }

  let newArgList = LabeledExprListSyntax(newArgs)
  let newCall = call.with(\.arguments, newArgList)
  return ExprSyntax(newCall)
}

private func makePathTupleExpr(_ pathValue: String) -> LabeledExprSyntax {
  let labelToken = TokenSyntax(.identifier("path"), presence: .present)
  let colonToken = TokenSyntax(.colon, trailingTrivia: .space, presence: .present)
  let stringExpr = makeStringLiteralExpr(pathValue)
  return LabeledExprSyntax(
    leadingTrivia: .newlines(1) + .spaces(2),
    label: labelToken,
    colon: colonToken,
    expression: stringExpr,
    trailingComma: nil)
}
