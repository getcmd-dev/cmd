// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

import LLMFoundation
// MARK: - ModelsView+Previews

#if DEBUG
#Preview {
  ModelsView(
    availableModels: LLMModel.allCases,
    availableProviders: LLMProvider.allCases,
    providerForModels: .constant([:]),
    inactiveModels: .constant([]),
    reasoningModels: .constant([:]))
    .frame(width: 600, height: 800)
}

#endif
