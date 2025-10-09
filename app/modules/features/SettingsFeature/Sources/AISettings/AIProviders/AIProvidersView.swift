// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import SwiftUI

// MARK: - AIProvidersView

public struct AIProvidersView: View {
  public init(viewModel: LLMSettingsViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
        PlainLink("Documentation", destination: URL(string: "https://docs.getcmd.dev/pages/ai-providers"))
          .font(.subheadline)
          .foregroundColor(.secondary)
          .padding(.bottom, 16)
        // Search bar
        HStack {
          Image(systemName: "magnifyingglass")
            .foregroundColor(.secondary)
            .frame(width: 16, height: 16)
          TextField("Search providers...", text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.bottom, 20)

        // Provider cards
        ScrollView {
          LazyVStack(spacing: 16) {
            ForEach(filteredProviders, id: \.provider) { providerInfo in
              AIProviderView(
                viewModel: viewModel,
                provider: providerInfo.provider,
                providerSettings: providerInfo.settings,
                isConnected: providerInfo.isConnected,
                enabledModels: viewModel.enabledModels,
                onSettingsChanged: { newSettings in
                  updateProviderSettings(for: providerInfo.provider, with: newSettings)
                },
                onSelectModels: {
                  providerToShowModelSelectionFor = providerInfo
                })
                .id(providerInfo.provider)
            }
          }
          .padding(.bottom, 20)
        }
      }
      if let providerInfo = providerToShowModelSelectionFor {
        ProviderModelSelectionView(
          viewModel: viewModel,
          provider: providerInfo.provider,
          providerSettings: providerInfo.settings,
          dismiss: {
            providerToShowModelSelectionFor = nil
          })
      }
    }
    .onAppear {
      setInitialOrder()
    }
  }

  @State private var providerToShowModelSelectionFor: ProviderInfo?

  @State private var orderedProviders: [AIProvider] = AIProvider.allCases

  @State private var searchText = ""

  @Bindable private var viewModel: LLMSettingsViewModel

  private var filteredProviders: [ProviderInfo] {
    let allProviders = orderedProviders.map { provider in
      let existingSettings = viewModel.providerSettings[provider]
      return ProviderInfo(
        provider: provider,
        settings: existingSettings,
        isConnected: provider.isConnected(existingSettings))
    }

    return searchText.isEmpty
      ? allProviders
      : allProviders.filter {
        $0.provider.name.localizedCaseInsensitiveContains(searchText)
      }
  }

  private var providerSettings: [AIProvider: AIProviderSettings] {
    viewModel.providerSettings
  }

  private func setInitialOrder() {
    orderedProviders = AIProvider.allCases.map { provider in
      (provider, provider.isConnected(viewModel.providerSettings[provider]))
    }.sorted { lhs, rhs in
      // Sort: connected first, then alphabetically
      if lhs.1 != rhs.1 {
        return lhs.1 && !rhs.1
      }
      return lhs.0.name < rhs.0.name
    }
    .map(\.0)
  }

  private func updateProviderSettings(for provider: AIProvider, with newSettings: AIProviderSettings?) {
    // Add new settings if provided
    if let newSettings {
      let createdOrder = providerSettings[provider]?.createdOrder ?? providerSettings.nextCreatedOrder
      let providerSettings = AIProviderSettings(
        apiKey: newSettings.apiKey,
        baseUrl: newSettings.baseUrl,
        executable: newSettings.executable,
        createdOrder: createdOrder)
      viewModel.save(providerSettings: providerSettings, for: provider)
    } else {
      // Remove existing settings for this provider
      viewModel.remove(provider: provider)
    }
  }
}

// MARK: - ProviderInfo

private struct ProviderInfo {
  let provider: AIProvider
  let settings: AIProviderSettings?
  let isConnected: Bool
}

// MARK: - ProviderModelSelectionView

private struct ProviderModelSelectionView: View {
  init(
    viewModel: LLMSettingsViewModel,
    provider: AIProvider,
    providerSettings: AIProviderSettings?,
    dismiss: @escaping () -> Void)
  {
    self.viewModel = viewModel
    self.provider = provider
    self.providerSettings = providerSettings
    self.dismiss = dismiss
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 16) {
        BackButton { dismiss() }

        AIProviderView(
          viewModel: viewModel,
          provider: provider,
          providerSettings: providerSettings,
          isConnected: true,
          enabledModels: viewModel.enabledModels,
          onSettingsChanged: nil,
          onSelectModels: nil)
      }
      .padding(.bottom, 16)

      ModelsView(viewModel: viewModel, provider: provider)
      Spacer(minLength: 0)
    }
    .onKeyPress(.escape) {
      dismiss()
      return .handled
    }.background(colorScheme.primaryBackground)
  }

  @Bindable private var viewModel: LLMSettingsViewModel

  @State private var searchText = ""
  @Environment(\.colorScheme) private var colorScheme

  private let provider: AIProvider
  private let providerSettings: AIProviderSettings?
  private let dismiss: () -> Void
}
