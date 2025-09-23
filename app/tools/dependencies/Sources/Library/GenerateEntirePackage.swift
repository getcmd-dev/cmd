// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - GenerateEntirePackage

/// Generate the root Package.swift file.
public final class GenerateEntirePackage {

  public init(packageDirPath: String) throws {
    self.packageDirPath = URL(filePath: packageDirPath).canonicalURL
    basePackageSource = try Parser.parse(source: String(contentsOfFile: packageDirPath))
  }

  public init(basePackageSource: SourceFileSyntax, packageDirPath: URL) {
    self.packageDirPath = packageDirPath.canonicalURL
    self.basePackageSource = basePackageSource
  }

  public func generate() throws -> SourceFileSyntax {
    let directoryPath = packageDirPath.path
    let modules = Self.findModuleFiles(in: directoryPath)

    let rewriter = try AddTargetToPackage(
      source: basePackageSource,
      packageDirPath: packageDirPath,
      modules: modules)

    return rewriter.rewrite()
  }

  let packageDirPath: URL
  let basePackageSource: SourceFileSyntax

  func generateSource() throws -> String {
    let rewrittenFile = try generate()

    return """
      // This file is generated. Do not modify directly.

      \(rewrittenFile.description)
      """
  }

  func run() throws {
    try generateSource().update(
      url: packageDirPath.appending(path: "/Package.swift"),
      atomically: true,
      encoding: .utf8)
  }

  private static func findModuleFiles(in directoryPath: String) -> [String] {
    let fileManager = FileManager.default
    var moduleFiles: [String] = []

    func searchDirectory(_ path: String) {
      let directoryURL = URL(fileURLWithPath: path)
      guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
        return
      }

      for case let fileURL as URL in enumerator {
        if fileURL.lastPathComponent == "Module.swift" {
          moduleFiles.append(fileURL.deletingLastPathComponent().path)
        }
      }
    }

    searchDirectory(directoryPath)
    return moduleFiles
  }
}

// MARK: - AddTargetToPackage

final class AddTargetToPackage {

  init(source: SourceFileSyntax, packageDirPath: URL, modules: [String]) throws {
    self.packageDirPath = packageDirPath
    packageFile = source

    let packageDir = packageDirPath.path
    moduleExpressions = try modules.map { modulePath in
      let content = try String(contentsOfFile: "\(modulePath)/Module.swift")
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
    var newStatements: [CodeBlockItemSyntax] = []

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

  private let packageDirPath: URL
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
  var newArgs: [LabeledExprSyntax] = []

  if let oldArgList = LabeledExprListSyntax(call.arguments) {
    for arg in oldArgList {
      if arg.label?.text == "path" {
        hadPath = true
        let updated = arg.with(\.expression, makeStringLiteralExpr(modulePath))
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
  let colonToken = TokenSyntax(.colon, presence: .present)
  let stringExpr = makeStringLiteralExpr(pathValue)
  return LabeledExprSyntax(
    leadingTrivia: .newline,
    label: labelToken,
    colon: colonToken,
    expression: stringExpr,
    trailingComma: nil)
}
