// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Position

struct Position: Codable, Equatable {
  let line: Int
  let character: Int
}

// MARK: - Range

struct Range: Codable, Equatable {
  let start: Position
  let end: Position
}

// MARK: - TextDocumentIdentifier

struct TextDocumentIdentifier: Codable {
  let uri: String
  let version: Int?

  init(uri: String, version: Int? = nil) {
    self.uri = uri
    self.version = version
  }
}

// MARK: - FormattingOptions

struct FormattingOptions: Codable {
  let tabSize: Int
  let insertSpaces: Bool
}

// MARK: - InitializeParams

struct InitializeParams: Codable {
  let processId: Int
  let rootUri: String?
  let initializationOptions: [String: AnyCodable]?
  let capabilities: ClientCapabilities
  let workspaceFolders: [WorkspaceFolder]?
}

// MARK: - ClientCapabilities

struct ClientCapabilities: Codable {
  let workspace: WorkspaceClientCapabilities?
  let textDocument: TextDocumentClientCapabilities?

  init() {
    workspace = WorkspaceClientCapabilities()
    textDocument = TextDocumentClientCapabilities()
  }
}

// MARK: - WorkspaceClientCapabilities

struct WorkspaceClientCapabilities: Codable {
  let workspaceFolders = true
  let configuration = true
}

// MARK: - TextDocumentClientCapabilities

struct TextDocumentClientCapabilities: Codable {
  let synchronization = TextDocumentSyncClientCapabilities()
}

// MARK: - TextDocumentSyncClientCapabilities

struct TextDocumentSyncClientCapabilities: Codable {
  let dynamicRegistration = true
  let willSave = true
  let willSaveWaitUntil = true
  let didSave = true
}

// MARK: - WorkspaceFolder

struct WorkspaceFolder: Codable {
  let uri: String
  let name: String
}

// MARK: - InitializeResult

struct InitializeResult: Codable {
  let capabilities: ServerCapabilities
}

// MARK: - ServerCapabilities

struct ServerCapabilities: Codable {
  // Add capabilities as needed
}

// MARK: - CopilotAccountStatus

enum CopilotAccountStatus: String, Codable {
  case ok = "OK"
  case notAuthorized = "NotAuthorized"
  case notSignedIn = "NotSignedIn"
  case maybeOk = "MaybeOK"
  case alreadySignedIn = "AlreadySignedIn"
}

// MARK: - SignInInitiateStatus

enum SignInInitiateStatus: String, Codable {
  case promptUserDeviceFlow = "PromptUserDeviceFlow"
  case alreadySignedIn = "AlreadySignedIn"
}

// MARK: - CheckStatusResult

struct CheckStatusResult: Codable {
  let status: CopilotAccountStatus
  let user: String?
}

// MARK: - SignInInitiateResult

struct SignInInitiateResult: Codable {
  let status: SignInInitiateStatus
  let userCode: String?
  let verificationUri: String?
  let expiresIn: Int?
  let interval: Int?
}

// MARK: - SignInConfirmParams

struct SignInConfirmParams: Codable {
  let userCode: String
}

// MARK: - SignInConfirmResult

struct SignInConfirmResult: Codable {
  let status: CopilotAccountStatus
  let user: String?
}

// MARK: - InlineCompletionParams

struct InlineCompletionParams: Codable {
  let textDocument: TextDocumentIdentifier
  let position: Position
  let formattingOptions: FormattingOptions
  let context: InlineCompletionContext
}

// MARK: - InlineCompletionContext

struct InlineCompletionContext: Codable {
  let triggerKind: Int // 0 = Automatic, 1 = Invoked
}

// MARK: - InlineCompletionList

struct InlineCompletionList: Codable {
  let items: [InlineCompletionItem]
}

// MARK: - InlineCompletionItem

struct InlineCompletionItem: Codable {
  let insertText: String
  let range: Range?
  let command: Command?
}

// MARK: - Command

struct Command: Codable {
  let title: String
  let command: String
  let arguments: [String]?
}

// MARK: - DidOpenTextDocumentParams

struct DidOpenTextDocumentParams: Codable {
  let textDocument: TextDocumentItem
}

// MARK: - TextDocumentItem

struct TextDocumentItem: Codable {
  let uri: String
  let languageId: String
  let version: Int
  let text: String
}

// MARK: - DidChangeTextDocumentParams

struct DidChangeTextDocumentParams: Codable {
  let textDocument: TextDocumentIdentifier
  let contentChanges: [TextDocumentContentChangeEvent]
}

// MARK: - TextDocumentContentChangeEvent

struct TextDocumentContentChangeEvent: Codable {
  let text: String
}

// MARK: - DidSaveTextDocumentParams

struct DidSaveTextDocumentParams: Codable {
  let textDocument: TextDocumentIdentifier
  let text: String?
}

// MARK: - DidCloseTextDocumentParams

struct DidCloseTextDocumentParams: Codable {
  let textDocument: TextDocumentIdentifier
}

// MARK: - CompletionTelemetryParams

struct CompletionTelemetryParams: Codable {
  let completionId: String
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
  init(_ value: Any) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map(\.value)
    } else if let dictionary = try? container.decode([String: AnyCodable].self) {
      value = dictionary.mapValues { $0.value }
    } else {
      value = NSNull()
    }
  }

  let value: Any

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    // Handle NSNumber explicitly to avoid ambiguity between Bool and Int
    if let number = value as? NSNumber {
      // Check if it's a boolean using CFBoolean
      let boolType = CFBooleanGetTypeID()
      let numberType = CFGetTypeID(number)
      if numberType == boolType {
        try container.encode(number.boolValue)
      } else if let int = number as? Int {
        try container.encode(int)
      } else if let double = number as? Double {
        try container.encode(double)
      } else {
        try container.encode(number.intValue)
      }
      return
    }

    switch value {
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let array as [Any]:
      try container.encode(array.map { AnyCodable($0) })
    case let dictionary as [String: Any]:
      try container.encode(dictionary.mapValues { AnyCodable($0) })
    default:
      try container.encodeNil()
    }
  }
}
