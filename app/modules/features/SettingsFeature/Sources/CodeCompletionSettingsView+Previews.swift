// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SettingsServiceInterface
import SwiftUI

#if DEBUG

#Preview("Code Completion Settings - Basic") {
  CodeCompletionSettingsView(
    enableCodeCompletion: .constant(true),
    codeCompletionDebounceMs: .constant(250),
    multiLineCodeCompletionDisplayMode: .constant(.expandCompletionOverExistingCodeWhenTriggered))
    .frame(width: 600, height: 600)
    .padding()
}

#Preview("Code Completion Settings - Advanced") {
  CodeCompletionSettingsView(
    enableCodeCompletion: .constant(true),
    codeCompletionDebounceMs: .constant(100),
    multiLineCodeCompletionDisplayMode: .constant(.expandCompletionOverExistingCode))
    .frame(width: 600, height: 600)
    .padding()
}

#endif
