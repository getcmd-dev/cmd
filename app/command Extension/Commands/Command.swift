// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface
import XcodeKit

// MARK: - CommandType

/// A base class for Xcode extension commands. It handles most of the boilerplate for the extension to work,
/// including having a timeout to ensure that each command will eventually complete and not freeze Xcode.
@objc
class CommandType: NSObject, XCSourceEditorCommand, @unchecked Sendable {

  /// The name of the command that will be displayed in Xcode.
  var name: String { fatalError(".name needs to be implemented in the subclass") }

  /// How long to wait before timing out the command.
  /// - Parameter invocation: The command invocation containing buffer and context
  /// - Returns: The timeout interval in seconds
  func timeout(_: XCSourceEditorCommandInvocation) -> TimeInterval { 1 }

  func handle(_: XCSourceEditorCommandInvocation) async throws {
    fatalError(".execute(with:)  needs to be implemented in the subclass")
  }
}

extension CommandType {
  var commandClassName: String { Self.className() }
  var identifier: String { commandClassName.replacingOccurrences(of: "_", with: "-") }

  @objc
  func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
    let completionHandler = UncheckedSendable(completionHandler)
    let timeout = timeout(invocation)
    let invocation = UncheckedSendable(invocation)

    let hasResponded = Atomic(false)

    let task = Task {
      var err: Error?
      do {
        try await self.handle(invocation.wrapped)
      } catch {
        err = error
      }

      let hasAlreadyResponded = hasResponded.mutate { value in
        defer { value = true }
        return value
      }

      if !hasAlreadyResponded {
        completionHandler.wrapped(err)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard self != nil else { return }

      let hasAlreadyResponded = hasResponded.mutate { value in
        defer { value = true }
        return value
      }

      guard !hasAlreadyResponded else {
        return
      }

      task.cancel()
      completionHandler.wrapped(XcodeExtensionError(message: "Timeout"))
    }
  }

  func makeCommandDefinition(identifierPrefix: String) -> [XCSourceEditorCommandDefinitionKey: Any] {
    [
      .classNameKey: commandClassName,
      .identifierKey: identifierPrefix + identifier,
      .nameKey: name,
    ]
  }
}
