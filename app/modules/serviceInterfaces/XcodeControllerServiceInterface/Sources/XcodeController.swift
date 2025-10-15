// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@_exported import FileDiffTypesFoundation
import Foundation

// MARK: - XcodeController

public protocol XcodeController: Sendable {
  /// Apply file changes to a project using Xcode.
  /// - Parameter fileChange: The file change to apply containing the target file and new content
  /// - Throws: An error if the file change cannot be applied
  func apply(fileChange: FileChange) async throws

  /// Build a project in Xcode.
  /// - Parameters:
  ///   - project: The URL of the project to build
  ///   - buildType: The type of build to perform (test or run)
  /// - Returns: A build section containing the build results, messages, and duration.
  /// If the build failes, a result will be return and the failures will be included in the sections.
  /// - Throws: An error if the build could not be triggered.
  func build(project: URL, buildType: BuildType) async throws -> BuildSection

  /// Open a file in Xcode at the specified location.
  /// - Parameters:
  ///   - file: The URL of the file to open
  ///   - line: The optional line number to navigate to
  ///   - column: The optional column number to navigate to
  /// - Throws: An error if the file cannot be opened
  func open(file: URL, line: Int?, column: Int?) async throws

  /// Execute an extension command by name.
  /// - Parameter commandName: The name of the extension command to execute
  /// - Throws: An error if the command cannot be executed
  func executeExtensionCommand(_ commandName: String) async throws
}

// MARK: - XcodeControllerProviding

public protocol XcodeControllerProviding {
  var xcodeController: XcodeController { get }
}

// MARK: - BuildType

public enum BuildType: String, Codable, Sendable {
  case test
  case run
}

// MARK: - BuildError

public struct BuildError: Error {
  public let exitCode: Int
  public let output: String

  public init(exitCode: Int, output: String) {
    self.exitCode = exitCode
    self.output = output
  }
}

// MARK: - BuildSection

public struct BuildSection: Codable, Sendable, Equatable {
  public init(title: String, messages: [BuildMessage], subSections: [BuildSection], duration: TimeInterval) {
    self.title = title
    self.messages = messages
    self.subSections = subSections
    self.duration = duration

    var maxSeverity = BuildMessage.Severity.info
    for message in messages {
      if message.severity.rawValue > maxSeverity.rawValue {
        maxSeverity = message.severity
      }
    }
    for section in subSections {
      let sectionSeverity = section.maxSeverity
      if sectionSeverity.rawValue > maxSeverity.rawValue {
        maxSeverity = sectionSeverity
      }
    }
    self.maxSeverity = maxSeverity
  }

  public let title: String
  public let messages: [BuildMessage]
  public let subSections: [BuildSection]
  public let duration: TimeInterval
  public let maxSeverity: BuildMessage.Severity

}

// MARK: - BuildMessage

public struct BuildMessage: Codable, Sendable, Equatable {
  public init(message: String, severity: Severity, location: Location?) {
    self.message = message
    self.severity = severity
    self.location = location
  }

  public enum Severity: Int, Codable, Sendable, RawRepresentable, Equatable {
    case info = 0
    case warning = 1
    case error = 2
  }

  public struct Location: Codable, Sendable, Equatable {
    public init(
      file: URL,
      startingLineNumber: Int?,
      startingColumnNumber: Int?,
      endingLineNumber: Int?,
      endingColumnNumber: Int?)
    {
      self.file = file
      self.startingLineNumber = startingLineNumber
      self.startingColumnNumber = startingColumnNumber
      self.endingLineNumber = endingLineNumber
      self.endingColumnNumber = endingColumnNumber
    }

    public let file: URL
    public let startingLineNumber: Int?
    public let startingColumnNumber: Int?
    public let endingLineNumber: Int?
    public let endingColumnNumber: Int?

  }

  public let message: String
  public let severity: Severity
  public let location: Location?

}
