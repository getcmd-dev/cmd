// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import Foundation
import SettingsServiceInterface
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockXcodeController: XcodeController {
  public init() { }

  public var onApplyFileChange: (@Sendable (FileChange, FileEditMode?) -> Void)?

  public var onBuild: (@Sendable (URL, BuildType) async throws -> BuildSection)?

  public var onOpen: (@Sendable (URL, Int?, Int?) async throws -> Void)?

  public var onExecuteExtensionCommand: (@Sendable (String) async throws -> Void)?

  public func executeExtensionCommand(_ commandName: String) async throws {
    try await onExecuteExtensionCommand?(commandName)
  }

  public func apply(fileChange: FileChange, editMode: FileEditMode? = nil) async throws {
    onApplyFileChange?(fileChange, editMode)
  }

  public func build(project: URL, buildType: BuildType) async throws -> BuildSection {
    if let onBuild {
      try await onBuild(project, buildType)
    } else {
      BuildSection(title: "Build", messages: [], subSections: [], duration: 0)
    }
  }

  public func open(file: URL, line: Int?, column: Int?) async throws {
    try await onOpen?(file, line, column)
  }

}
#endif
