// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import ThreadSafe

@ThreadSafe
public final class MockXcodeObserver: XcodeObserver {

  public init(
    _ initialValue: AXState<XcodeState> = .unknown)
  {
    mutableStatePublisher = .init(initialValue)
  }

  public convenience init(
    _ initialValue: AXState<XcodeState> = .unknown,
    fileManager: FileManagerI)
  {
    self.init(initialValue)
    onGetContent = { [weak self] file in
      guard let content = self?.knownEditorContent(of: file) ?? (try? fileManager.read(contentsOf: file, encoding: .utf8)) else {
        throw AppError("Could not read content of \(file.path)")
      }
      return content
    }
  }

  public let mutableStatePublisher: CurrentValueSubject<AXState<XcodeState>, Never>
  public var onGetContent: @Sendable (URL) throws -> String = { _ in throw AppError("Could not read content of file") }
  public var onListFiles: @Sendable (URL) async throws -> ([URL], WorkspaceType) = { _ in
    throw AppError("Could not list files in workspace")
  }

  public var axNotifications: AnyPublisher<AXNotification, Never> {
    Just(AXNotification.applicationActivated).eraseToAnyPublisher()
  }

  public var statePublisher: ReadonlyCurrentValueSubject<AXState<XcodeState>, Never> {
    mutableStatePublisher.readonly()
  }

  public func getContent(of file: URL) throws -> String {
    try onGetContent(file)
  }

  public func listFiles(in workspace: URL) async throws -> ([URL], WorkspaceType) {
    try await onListFiles(workspace)
  }

}
