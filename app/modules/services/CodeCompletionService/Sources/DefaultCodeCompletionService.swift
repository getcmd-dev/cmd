// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import DependencyFoundation
import Foundation
import SettingsServiceInterface
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - DefaultCodeCompletionService

@ThreadSafe
final class DefaultCodeCompletionService: CodeCompletionService, @unchecked Sendable {
  init(
    xcodeObserver: XcodeObserver,
    getPasteboardContent: @escaping @Sendable () -> String?,
    codeCompletionProviders: [any CodeCompletionProvider],
    settingsService: SettingsService)
  {
    self.xcodeObserver = xcodeObserver
    self.getPasteboardContent = getPasteboardContent
    self.codeCompletionProviders = codeCompletionProviders
    self.settingsService = settingsService
  }

  var configuredProvider: (any CodeCompletionProvider)? {
    if let id = settingsService.value(for: \.codeCompletionProviderId) {
      return codeCompletionProviders.first(where: { $0.id == id })
    }
    return nil
  }

  func provideCompletion(timeout _: TimeInterval) async throws -> CompletionSuggestion {
    guard let provider = configuredProvider else {
      throw AppError("No code completion provider configured")
    }
    guard let workspace = xcodeObserver.state.focusedWorkspace else {
      throw AppError("No focused Xcode workspace")
    }
    guard let focussedFile = await xcodeObserver.focusedTabURL(in: workspace) else {
      throw AppError("No focused file in Xcode workspace")
    }
    guard let editor = workspace.editors.first(where: { $0.isFocused }) else {
      throw AppError("No focused editor in Xcode workspace")
    }
    let selections = editor.selections
    guard selections.count == 1, let selection = selections.first else {
      throw AppError("Multiple selections are not supported")
    }

    let content = editor.content

    return try await provider.provideCompletion()
  }

  func logCompletionAcceptance(suggestion _: CompletionSuggestion, accepted _: Bool) { }

  private let xcodeObserver: XcodeObserver
  private let getPasteboardContent: @Sendable () -> String?
  private let codeCompletionProviders: [any CodeCompletionProvider]
  private let settingsService: SettingsService

}

extension BaseProviding where
  Self: XcodeObserverProviding,
  Self: CodeCompletionProvidersPluginProviding,
  Self: SettingsServiceProviding
{
  public var codeCompletionService: CodeCompletionService {
    shared {
      DefaultCodeCompletionService(
        xcodeObserver: xcodeObserver,
        getPasteboardContent: { NSPasteboard.general.string(forType: .string) },
        codeCompletionProviders: codeCompletionProviders,
        settingsService: settingsService)
    }
  }
}
