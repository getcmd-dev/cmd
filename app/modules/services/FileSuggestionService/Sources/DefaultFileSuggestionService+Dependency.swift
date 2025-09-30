// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation
import FileSuggestionServiceInterface
import XcodeObserverServiceInterface

extension BaseProviding where
  Self: XcodeObserverProviding
{
  public var fileSuggestionService: FileSuggestionService {
    shared {
      DefaultFileSuggestionService(
        xcodeObserver: xcodeObserver)
    }
  }
}
