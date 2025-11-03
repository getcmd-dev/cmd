// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
// MARK: - OnboardingFeatureBuilder

public enum CodeCompletionFeatureBuilder {
  @MainActor
  public static func build() -> AnyView {
    let viewModel = CodeCompletionViewModel()
    return AnyView(CodeCompletionView(viewModel: viewModel))
  }

}
