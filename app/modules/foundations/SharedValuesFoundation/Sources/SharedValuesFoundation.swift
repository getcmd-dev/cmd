// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation

// MARK: - ExtensionRequest

/// Represents a request from the extension to the host app
public enum ExtensionRequest: Codable, Sendable {
  case getQueuedInput
  case sendResult(ExtensionResult)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "getQueuedInput":
      self = .getQueuedInput

    case "sendResult":
      let result = try container.decode(ExtensionResult.self, forKey: .result)
      self = .sendResult(result)

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown extension request type: \(type)")
    }
  }

  public enum CodingKeys: String, CodingKey {
    case type
    case result
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .getQueuedInput:
      try container.encode("getQueuedInput", forKey: .type)
    case .sendResult(let result):
      try container.encode("sendResult", forKey: .type)
      try container.encode(result, forKey: .result)
    }
  }
}

// MARK: - ExtensionInput

/// Represents the input sent from the host app to the extension
public enum ExtensionInput: Codable, Sendable {
  case applyEdit(FileChange)
  case reloadSettings
  case getFormattingMetadata
  case error(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "applyEdit":
      let fileChange = try container.decode(FileChange.self, forKey: .fileChange)
      self = .applyEdit(fileChange)

    case "reloadSettings":
      self = .reloadSettings

    case "getFormattingMetadata":
      self = .getFormattingMetadata

    case "error":
      let errorMessage = try container.decode(String.self, forKey: .error)
      self = .error(errorMessage)

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown extension input type: \(type)")
    }
  }

  public enum CodingKeys: String, CodingKey {
    case type
    case fileChange
    case error
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .applyEdit(let fileChange):
      try container.encode("applyEdit", forKey: .type)
      try container.encode(fileChange, forKey: .fileChange)

    case .reloadSettings:
      try container.encode("reloadSettings", forKey: .type)

    case .getFormattingMetadata:
      try container.encode("getFormattingMetadata", forKey: .type)

    case .error(let errorMessage):
      try container.encode("error", forKey: .type)
      try container.encode(errorMessage, forKey: .error)
    }
  }
}

// MARK: - ExtensionResult

/// Represents the result from executing an extension command
public enum ExtensionResult: Codable, Sendable {
  case applyEditResult(Result<Void, ExtensionError>)
  case reloadSettingsResult
  case formattingMetadataResult(Result<FileFormattingMetadata, ExtensionError>)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "applyEditResult":
      if let errorMessage = try container.decodeIfPresent(String.self, forKey: .error) {
        self = .applyEditResult(.failure(ExtensionError(message: errorMessage)))
      } else {
        self = .applyEditResult(.success(()))
      }

    case "reloadSettingsResult":
      self = .reloadSettingsResult

    case "formattingMetadataResult":
      if let errorMessage = try container.decodeIfPresent(String.self, forKey: .error) {
        self = .formattingMetadataResult(.failure(ExtensionError(message: errorMessage)))
      } else {
        let metadata = try container.decode(FileFormattingMetadata.self, forKey: .metadata)
        self = .formattingMetadataResult(.success(metadata))
      }

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown extension result type: \(type)")
    }
  }

  public enum CodingKeys: String, CodingKey {
    case type
    case success
    case error
    case metadata
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .applyEditResult(let result):
      try container.encode("applyEditResult", forKey: .type)
      switch result {
      case .success:
        try container.encode(true, forKey: .success)
      case .failure(let error):
        try container.encode(error.message, forKey: .error)
      }

    case .reloadSettingsResult:
      try container.encode("reloadSettingsResult", forKey: .type)

    case .formattingMetadataResult(let result):
      try container.encode("formattingMetadataResult", forKey: .type)
      switch result {
      case .success(let metadata):
        try container.encode(metadata, forKey: .metadata)
      case .failure(let error):
        try container.encode(error.message, forKey: .error)
      }
    }
  }
}

// MARK: - ExtensionError

public struct ExtensionError: Error, Codable, Sendable {
  public let message: String

  public init(message: String) {
    self.message = message
  }
}

// MARK: - ExtensionTimeout

public enum ExtensionTimeout {
  public static let applyFileChangeTimeout: TimeInterval = 2
}

// MARK: - ExtensionCommandNames

public enum ExtensionCommandNames {
  public static let cmd = "Cmd"
  public static let executeUserDefinedShortcut = "executeUserDefinedXcodeShortcut"
}

// MARK: - FileChangeConfirmation

public struct FileChangeConfirmation: Codable, Sendable {
  public let id: String
  public let error: String?

  public init(id: String, error: String?) {
    self.id = id
    self.error = error
  }
}

// MARK: - EmptyInput

public struct EmptyInput: Codable {
  public init() { }
}

// MARK: - EmptyResponse

public struct EmptyResponse: Codable, Sendable {
  public init() { }
}

// MARK: - UserDefinedXcodeShortcutLimits

public enum UserDefinedXcodeShortcutLimits {
  /// Maximum number of user defined Xcode shortcuts that can be registered simultaneously
  public static let maxShortcuts = 10
}

// MARK: - UserDefinedXcodeShortcutExecutionInput

/// Parameters to execute an Xcode shortcut that has been defined by the user.
public struct UserDefinedXcodeShortcutExecutionInput: Codable {
  public let shortcutId: String
  public let shellCommand: String

  public init(shortcutId: String, shellCommand: String) {
    self.shortcutId = shortcutId
    self.shellCommand = shellCommand
  }
}

// MARK: - UserDefinedShortcutRequest

/// Extension request structure for user-defined shortcuts
/// Uses a command string pattern to allow users to define custom commands
public struct UserDefinedShortcutRequest<Input: Codable>: Codable {
  public let type = "execute-command"
  public let command: String
  public let input: Input

  public init(command: String, input: Input) {
    self.command = command
    self.input = input
  }

  public init(from decoder: any Decoder) throws {
    let container: KeyedDecodingContainer<UserDefinedShortcutRequest<Input>.CodingKeys> = try decoder
      .container(keyedBy: UserDefinedShortcutRequest<Input>.CodingKeys.self)
    command = try container.decode(String.self, forKey: UserDefinedShortcutRequest<Input>.CodingKeys.command)
    input = try container.decode(Input.self, forKey: UserDefinedShortcutRequest<Input>.CodingKeys.input)
  }
}

// MARK: - FileFormattingMetadata

/// Formatting metadata for a file extracted from Xcode's buffer
public struct FileFormattingMetadata: Codable, Sendable, Equatable {
  public let tabSize: Int
  public let indentSize: Int
  public let usesTabsForIndentation: Bool
  public let uti: String?

  public init(tabSize: Int, indentSize: Int, usesTabsForIndentation: Bool, uti: String?) {
    self.tabSize = tabSize
    self.indentSize = indentSize
    self.usesTabsForIndentation = usesTabsForIndentation
    self.uti = uti
  }
}

// MARK: - SharedKeys

public enum SharedKeys {
  public static let pointReleaseXcodeExtensionToDebugApp = "pointReleaseXcodeExtensionToDebugApp"
}
