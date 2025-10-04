// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import SettingsServiceInterface
import SwiftUI

#if DEBUG

// MARK: - Helper for Providers Previews

#Preview("Providers - Empty State") {
  withDependencies({
    $0.settingsService = MockSettingsService(anthropicAPIKey: nil, openAIAPIKey: nil)
  }) {
    AIProvidersView(viewModel: LLMSettingsViewModel())
      .frame(width: 600, height: 400)
      .padding()
  }
}

// #Preview("Providers - Single Provider") {
//  withDependencies({
//    $0.settingsService = MockSettingsService(anthropicAPIKey: "test", openAIAPIKey: nil)
//  }) {
//    AIProvidersView(providerSettings: .constant([
//      .anthropic: .init(apiKey: "sk-ant-api03-..."),
//    ]))
//    .frame(width: 600, height: 400)
//    .padding()
//  }
// }
//
// #Preview("Providers - Multiple Providers") {
//  withDependencies({
//    $0.settingsService = MockSettingsService(
//      anthropicAPIKey: "sk-ant-api03-...",
//      openAIAPIKey: "sk-...")
//  }) {
//    AIProvidersView(providerSettings: .constant([
//      .anthropic: .init(apiKey: "sk-ant-api03-..."),
//      .openAI: .init(apiKey: "sk-..."),
//    ]))
//    .frame(width: 600, height: 500)
//    .padding()
//  }
// }

#endif
