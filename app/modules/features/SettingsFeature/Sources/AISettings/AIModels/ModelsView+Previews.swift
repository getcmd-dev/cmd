// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import LLMServiceInterface
import SettingsServiceInterface
import SwiftUI

import LLMFoundation
// MARK: - ModelsView+Previews

#if DEBUG
#Preview {
  withDependencies({
    // TODO: mock correctly to have a meaningful preview
    $0.llmService = MockLLMService()
    $0.settingsService = MockSettingsService()
  }) {
    ModelsView(
      viewModel: LLMSettingsViewModel())
      .frame(width: 600, height: 800)
  }
}

#endif
