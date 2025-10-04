// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import SwiftUI

// MARK: - Input

public struct Input {
  let bringWindowToFront: @MainActor () -> Void
  let onDone: @MainActor () -> Void
  let createAIProvidersView: @MainActor () -> AnyView

  public init(
    bringWindowToFront: @MainActor @escaping () -> Void,
    onDone: @MainActor @escaping () -> Void,
    createAIProvidersView: @MainActor @escaping () -> AnyView)
  {
    self.bringWindowToFront = bringWindowToFront
    self.onDone = onDone
    self.createAIProvidersView = createAIProvidersView
  }
}

// MARK: - OnboardingFeatureBuilder

public enum OnboardingFeatureBuilder {
  @MainActor
  public static func build(_ input: Input) -> AnyView {
    let viewModel = OnboardingViewModel(
      bringWindowToFront: input.bringWindowToFront,
      onDone: input.onDone)
    return AnyView(OnboardingView(viewModel: viewModel, createAIProvidersView: input.createAIProvidersView))
  }

}
