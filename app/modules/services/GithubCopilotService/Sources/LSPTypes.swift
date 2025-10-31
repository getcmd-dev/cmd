// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// TODO: look at moving to using https://github.com/ChimeHQ/LanguageClient if we need more LSP functionality / type safety.

import Foundation
import JSONFoundation

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

struct InitializeParams: Encodable {
  let processId: Int
  let rootUri: String?
  let initializationOptions: [String: JSON.Value]?
  let capabilities: ClientCapabilities
  let workspaceFolders: [WorkspaceFolder]?
}

// MARK: - ClientCapabilities

struct ClientCapabilities: Encodable {
  let workspace: WorkspaceClientCapabilities?
  let textDocument: TextDocumentClientCapabilities?

  init() {
    workspace = WorkspaceClientCapabilities()
    textDocument = TextDocumentClientCapabilities()
  }
}

// MARK: - WorkspaceClientCapabilities

struct WorkspaceClientCapabilities: Encodable {
  let workspaceFolders = true
  let configuration = true
}

// MARK: - TextDocumentClientCapabilities

struct TextDocumentClientCapabilities: Encodable {
  let synchronization = TextDocumentSyncClientCapabilities()
}

// MARK: - TextDocumentSyncClientCapabilities

struct TextDocumentSyncClientCapabilities: Encodable {
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

// MARK: - CheckStatusResult

struct CheckStatusResult: Codable {
  let status: CopilotAccountStatus
  let user: String?
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

// MARK: - DidChangeStatusNotificationParams

struct DidChangeStatusNotificationParams: Decodable {
  let kind: String
}

// MARK: - WorkspaceConfigurationRequestParameters

/// workspace/configuration
struct WorkspaceConfigurationRequestParameters: Decodable {
  let items: [ConfigurationItem]

  struct ConfigurationItem: Decodable {
    let section: String
  }
}
