// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Constants

private enum Constants {
  static let trackedMacroName = "ThreadSafeProperty"
  static let initializerMacroName = "ThreadSafeInitializer"
  static let internalStateName = "_internalState"
}

// MARK: - ThreadSafeMacro

/// A macro that makes class properties thread-safe by using an atomic internal state.
public struct ThreadSafeMacro {
  public init() { }
}

// MARK: MemberMacro

extension ThreadSafeMacro: MemberMacro {
  /// Adds the internal state type and its corresponding property to the class.
  public static func expansion(
    of _: AttributeSyntax,
    providingMembersOf declaration: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext)
    throws -> [DeclSyntax]
  {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else { return [] }
    let storedVariables = classDecl.storedVariables

    var members: [DeclSyntax] = []

    // Generate _internalState property
    let internalStateProperty = DeclSyntax("""
      private let \(raw: Constants.internalStateName): Atomic<_InternalState>
      """)
    members.append(internalStateProperty)

    // Generate _InternalState struct with the stored properties
    var internalStateFields = ""
    for (name, type, _) in storedVariables {
      internalStateFields += "  var \(name): \(type)\n"
    }

    let internalStateStruct = DeclSyntax("""
      private struct _InternalState: Sendable {
      \(raw: internalStateFields)}
      """)
    members.append(internalStateStruct)

    // Generate `inLock` function
    let mutateFunc = DeclSyntax("""
        @discardableResult
        private func inLock<Result: Sendable>(_ mutation: @Sendable (inout _InternalState) -> Result) -> Result {
          _internalState.mutate(mutation)
        }
      """)
    members.append(mutateFunc)

    return members
  }
}

// MARK: MemberAttributeMacro

extension ThreadSafeMacro: MemberAttributeMacro {
  /// Adds `@ThreadSafeProperty` and `@ThreadSafeInitializer` attributes to the class members.
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo group: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext)
    throws -> [AttributeSyntax]
  {
    // Add @ThreadSafeProperty to stored var properties
    if
      let property = member.as(VariableDeclSyntax.self),
      property.isMutable
    {
      // Don't apply if the property is already tracked
      if
        property.attributes.contains(where: {
          $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == Constants.trackedMacroName
        })
      {
        return []
      }

      // Apply the @ThreadSafeProperty attribute
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier(Constants.trackedMacroName))),
      ]
    }

    // Add @ThreadSafeInitializer to initializers (not convenience ones)
    if
      let initDecl = member.as(InitializerDeclSyntax.self),
      !initDecl.modifiers.contains(where: { $0.name.text == "convenience" })
    {
      guard let classDecl = group.as(ClassDeclSyntax.self) else { return [] }
      let storedVariablesNames = classDecl.storedVariables

      let argumentListExpr: String = {
        if storedVariablesNames.isEmpty { return "[:]" }
        let arguments = storedVariablesNames.map { key, type, defaultValue in
          if let defaultValue {
            "\"\(key)\": TypeInfo<\(type)>(defaultValue: \(defaultValue)),"
          } else {
            "\"\(key)\": TypeInfo<\(type)>(),"
          }
        }.joined(separator: "\n")
        return "[\n\(arguments)\n]"
      }()

      let argumentList = LabeledExprListSyntax(
        [
          LabeledExprSyntax(
            expression: ExprSyntax(stringLiteral: argumentListExpr)),
        ])

      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier(Constants.initializerMacroName)),
          leftParen: TokenSyntax.leftParenToken(),
          arguments: AttributeSyntax.Arguments.argumentList(argumentList),
          rightParen: TokenSyntax.rightParenToken()),
      ]
    }

    return []
  }
}

// MARK: - ThreadSafeInitializerMacro

public struct ThreadSafeInitializerMacro { }

// MARK: BodyMacro

extension ThreadSafeInitializerMacro: BodyMacro {
  /// Rewrites the initializer to initialize the internal state with the stored properties.
  public static func expansion(
    of syntax: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in _: some MacroExpansionContext)
    throws -> [CodeBlockItemSyntax]
  {
    guard
      let decl = declaration.body,
      let argument = syntax.arguments?.as(LabeledExprListSyntax.self)?.first
    else {
      return []
    }

    // Parse arguments
    guard
      let dictExpr = argument.expression.as(DictionaryExprSyntax.self),
      let elements = dictExpr.content.as(DictionaryElementListSyntax.self)
    else {
      // Not a dictionary => do nothing
      return decl.statements.compactMap { CodeBlockItemSyntax($0) }
    }

    let storedVariables: [(key: String, type: String, defaultValue: String?)] = elements.compactMap { element in
      // Parse the key
      guard
        let stringLiteral = element.key.as(StringLiteralExprSyntax.self),
        let firstSegment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
      else {
        return nil
      }
      let keyName = firstSegment.content.text

      // Parse the type
      guard
        let callExpr = element.value.as(FunctionCallExprSyntax.self),
        let genericType = callExpr.calledExpression.as(GenericSpecializationExprSyntax.self),
        let typeName = genericType.genericArgumentClause.arguments.first?.argument.description
          .trimmingCharacters(in: .whitespacesAndNewlines)
      else {
        return nil
      }

      // Parse the optional default value
      var defaultValue: String? = nil
      for arg in callExpr.arguments {
        if arg.label?.text == "defaultValue" {
          defaultValue = arg.expression.description
        }
      }
      if defaultValue == nil, typeName.hasSuffix("?") { defaultValue = "nil" }

      return (
        key: keyName,
        type: typeName,
        defaultValue: defaultValue)
    }

    // Find when the last stored variable is set
    let lastVariableSetAt = decl.statements.enumerated().compactMap { offset, statement in
      for (key, _, _) in storedVariables.filter({ $0.defaultValue == nil }) {
        let trimmedStatement = statement.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if
          trimmedStatement.starts(with: "self.\(key) = ") ||
          trimmedStatement.starts(with: "\(key) = ")
        {
          return (offset: offset, element: key)
        }
      }
      return nil
    }.last?.offset ?? -1

    // Replace foo = ... by _foo = ... for all stored properties
    var mutatedProperties = Set<String>()
    var statements: [CodeBlockItemSyntax?] = decl.statements.enumerated().flatMap { offset, statement -> [CodeBlockItemSyntax?] in
      if offset > lastVariableSetAt {
        return [CodeBlockItemSyntax(statement)]
      }
      let trimmedStatement = statement.description.trimmingCharacters(in: .whitespacesAndNewlines)
      for (key, _, _) in storedVariables {
        if trimmedStatement.starts(with: "self.\(key) = ") {
          mutatedProperties.insert(key)
          return [
            CodeBlockItemSyntax(stringLiteral: statement.description.replacing("self.\(key) = ", with: "_\(key) = ")),
          ]
        }
        if trimmedStatement.starts(with: "\(key) = ") {
          mutatedProperties.insert(key)
          return [
            CodeBlockItemSyntax(stringLiteral: statement.description.replacing("\(key) = ", with: "_\(key) = ")),
          ]
        }
      }
      return [CodeBlockItemSyntax(statement)]
    }

    // Set _internalState once the required properties have been set
    let addedStatement = CodeBlockItemSyntax(
      stringLiteral: "self._internalState = Atomic<_InternalState>(_InternalState(\(storedVariables.map { "\($0.key): _\($0.key)" }.joined(separator: ", "))))")
    statements.insert(addedStatement, at: lastVariableSetAt + 1)

    // Add variables to hold the properties while they are created
    for (key, type, defaultValue) in storedVariables.reversed() {
      let isMutated = mutatedProperties.contains(key)
      if let defaultValue {
        statements.insert(
          CodeBlockItemSyntax(stringLiteral: "\(isMutated ? "var" : "let") _\(key): \(type) = \(defaultValue)"),
          at: 0)
      } else {
        statements.insert(CodeBlockItemSyntax(stringLiteral: "\(isMutated ? "var" : "let") _\(key): \(type)"), at: 0)
      }
    }

    return statements.compactMap(\.self)
  }
}

// MARK: - ThreadSafePropertyMacro

public struct ThreadSafePropertyMacro: AccessorMacro {
  /// Adds a getter pointing to the internal state for each property marked with `@ThreadSafeProperty`.
  public static func expansion(
    of _: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext)
    throws -> [AccessorDeclSyntax]
  {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let identifier = property.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    else {
      return []
    }

    // Generate getter/setter
    return [
      AccessorDeclSyntax(stringLiteral: "get { \(Constants.internalStateName).value.\(identifier) }"),
      AccessorDeclSyntax(stringLiteral: "set { _ = \(Constants.internalStateName).set(\\.\(identifier), to: newValue) }"),
    ]
  }
}

// MARK: - SendableDiagnostic

struct SendableDiagnostic: DiagnosticMessage {
  let message: String
  let diagnosticID = MessageID(domain: "ThreadSafeMacro", id: "propertyReplacement")
  let severity = DiagnosticSeverity.error
}

// MARK: - DiagnosticsError Extension

extension DiagnosticsError {
  init(syntax: some SyntaxProtocol, message: String) {
    self.init(diagnostics: [
      Diagnostic(node: Syntax(syntax), message: SendableDiagnostic(message: message)),
    ])
  }
}

// MARK: - ClassDeclSyntax Extension

extension ClassDeclSyntax {
  /// Returns the list of mutable stored properties in the class.
  var storedVariables: [(name: String, type: String, defaultValue: String?)] {
    var storedVars: [(String, String, String?)] = []

    for member in memberBlock.members {
      guard
        let varDecl = member.decl.as(VariableDeclSyntax.self),
        varDecl.isMutable
      else { continue }

      for binding in varDecl.bindings {
        if
          binding.accessorBlock == nil,
          let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        {
          let name = pattern.identifier.text.trimmingCharacters(in: .whitespacesAndNewlines)
          let defaultValue = binding.initializer?.value.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? binding
            .typeAnnotation?.type.defaultValueForOptional

          if let typeAnnotation = binding.typeAnnotation {
            let type = typeAnnotation.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            storedVars.append((name, type, defaultValue))
          } else if let defaultValue {
            // Heuristically tries to infer the type from the default value
            let value = defaultValue.replacing(/\(.*\)/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)

            let type: String =
              if value == "true" || value == "false" {
                "Bool"
              } else if value.firstMatch(of: /^-?\d+$/) != nil {
                "Int"
              } else if value.firstMatch(of: /^-?\d+\.?\d*$/) != nil {
                "Double"
              } else if value.firstMatch(of: /^".*"$/) != nil {
                "String"
              } else {
                value
              }
            storedVars.append((name, type, defaultValue))
          }
        }
      }
    }
    return storedVars
  }
}

extension VariableDeclSyntax {
  var isMutable: Bool {
    guard
      bindingSpecifier.text == "var",
      attributes.isEmpty,
      bindings.count == 1,
      let binding = bindings.first,
      binding.accessorBlock == nil,
      let _ = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
      return false
    }
    return true
  }
}

extension TypeSyntax {
  var defaultValueForOptional: String? {
    if self.as(OptionalTypeSyntax.self) != nil {
      return "nil"
    }
    return nil
  }
}
