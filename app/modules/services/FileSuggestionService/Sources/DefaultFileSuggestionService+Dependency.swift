// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation
import FileSuggestionServiceInterface
import FoundationInterfaces
import ShellServiceInterface
import XcodeObserverServiceInterface

extension BaseProviding where
  Self: ShellServiceProviding,
  Self: FileManagerProviding,
  Self: XcodeObserverProviding
{
  public var fileSuggestionService: FileSuggestionService {
    shared {
      DefaultFileSuggestionService(
        fileManager: fileManager,
        shellService: shellService,
        xcodeObserver: xcodeObserver)
    }
  }
}
