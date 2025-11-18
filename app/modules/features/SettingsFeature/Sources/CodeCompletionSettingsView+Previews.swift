// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI

#if DEBUG

#Preview("Code Completion Settings - Basic", traits: .emptyRouter) {
  CodeCompletionSettingsView(
    enableCodeCompletion: .mutable(true),
    codeCompletionDebounceMs: .mutable(250),
    multiLineCodeCompletionDisplayMode: .mutable(.expandCompletionOverExistingCodeWhenTriggered))
    .frame(width: 600, height: 600)
    .padding()
}

#Preview("Code Completion Settings - Advanced", traits: .emptyRouter) {
  CodeCompletionSettingsView(
    enableCodeCompletion: .mutable(true),
    codeCompletionDebounceMs: .mutable(100),
    multiLineCodeCompletionDisplayMode: .mutable(.expandCompletionOverExistingCode))
    .frame(width: 600, height: 600)
    .padding()
}

#endif
