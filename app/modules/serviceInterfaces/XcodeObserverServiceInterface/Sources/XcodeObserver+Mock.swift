// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation

public final class MockXcodeObserver: XcodeObserver {

  public init(
    _ initialValue: AXState<XcodeState>,
    filesContentOnDisk: [URL: String] = [:])
  {
    mutableStatePublisher = .init(initialValue)
    self.filesContentOnDisk = filesContentOnDisk
  }

  public let mutableStatePublisher: CurrentValueSubject<AXState<XcodeState>, Never>

  public var axNotifications: AnyPublisher<AXNotification, Never> {
    Just(AXNotification.applicationActivated).eraseToAnyPublisher()
  }

  public var statePublisher: ReadonlyCurrentValueSubject<AXState<XcodeState>, Never> {
    mutableStatePublisher.readonly()
  }

  public func getContent(of file: URL) throws -> String {
    guard let content = knownEditorContent(of: file) ?? filesContentOnDisk[file] else {
      throw AppError("Could not read content of \(file.path)")
    }
    return content
  }

  private let filesContentOnDisk: [URL: String]

}
