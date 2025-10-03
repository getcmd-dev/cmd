// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import SwiftUI

// MARK: - ProvidersView

public struct ProvidersView: View {
  public init(viewModel: LLMSettingsViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 0) {
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
              ProviderCard(
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

  @State private var orderedProviders: [LLMProvider] = LLMProvider.allCases

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

  private var providerSettings: [LLMProvider: LLMProviderSettings] {
    viewModel.providerSettings
  }

  private func setInitialOrder() {
    orderedProviders = LLMProvider.allCases.map { provider in
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

  private func updateProviderSettings(for provider: LLMProvider, with newSettings: LLMProviderSettings?) {
    // Add new settings if provided
    if let newSettings {
      let createdOrder = providerSettings[provider]?.createdOrder ?? providerSettings.nextCreatedOrder
      let providerSettings = LLMProviderSettings(
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
  let provider: LLMProvider
  let settings: LLMProviderSettings?
  let isConnected: Bool
}

// MARK: - ProviderCard

private struct ProviderCard: View {
  init(
    viewModel: LLMSettingsViewModel,
    provider: LLMProvider,
    providerSettings: LLMProviderSettings?,
    isConnected: Bool,
    enabledModels: [ModelInfoId],
    onSettingsChanged: ((LLMProviderSettings?) -> Void)?,
    onSelectModels: (() -> Void)?)
  {
    self.viewModel = viewModel
    self.provider = provider
    self.providerSettings = providerSettings
    self.isConnected = isConnected
    self.enabledModels = enabledModels
    self.onSettingsChanged = onSettingsChanged
    self.onSelectModels = onSelectModels
  }

  var isConfigurable: Bool {
    onSettingsChanged != nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(provider.name)
              .font(.title2)
              .fontWeight(.medium)
            Spacer()
            Text(isConnected ? "Connected" : "Not connected")
              .font(.subheadline)
              .foregroundColor(isConnected ? colorScheme.addedLineDiffText : .secondary)
          }

          if let websiteURL = provider.websiteURL {
            PlainLink(provider.description, destination: websiteURL)
              .font(.subheadline)
              .foregroundColor(.secondary)
          } else {
            Text(provider.description)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }

      if isConfigurable {
        // API Key section
        if provider.needsAPIKey {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("API Key")
                .font(.subheadline)
                .fontWeight(.medium)
              Spacer(minLength: 0)
              if let apiKeyCreationURL = provider.apiKeyCreationURL {
                PlainLink("open API keys page", destination: apiKeyCreationURL)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .fontWeight(.medium)
              }
            }

            HStack {
              if showAPIKey {
                TextField("Enter API key...", text: $apiKey)
                  .textFieldStyle(.plain)
              } else {
                SecureField("Enter API key...", text: $apiKey)
                  .textFieldStyle(.plain)
              }

              if !apiKey.isEmpty {
                Button(action: { showAPIKey.toggle() }) {
                  Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.3))

            Text("API keys are stored securely in the keychain")
              .font(.footnote)
              .foregroundColor(.secondary)
          }
        }

        // Local executable section (for providers that are local)
        if let externalAgent = provider.externalAgent {
          ExternalAgentCard(externalAgent: externalAgent, executable: $executable)
        }
      }

      // Models button
      if isConnected, let onSelectModels, provider.externalAgent == nil {
        Button(action: {
          onSelectModels()
        }) {
          HStack {
            Text("\(enabledModelsCount) models enabled")
              .font(.subheadline)
              .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
          }
          .foregroundColor(.primary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(NSColor.textBackgroundColor))
          .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.3))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(16)
    .background(Color(NSColor.controlBackgroundColor))
    .with(cornerRadius: 12, borderColor: Color.gray.opacity(0.2))
    .onAppear {
      loadCurrentSettings()
    }
    .onChange(of: apiKey) { _, _ in
      saveSettings()
    }
    .onChange(of: executable) { _, _ in
      saveSettings()
    }
  }

  @Bindable private var viewModel: LLMSettingsViewModel
  @Environment(\.colorScheme) private var colorScheme

  @State private var apiKey = ""
  @State private var baseURL = ""
  @State private var executable = ""
  @State private var showAPIKey = false

  private let enabledModels: [ModelInfoId]

  private let provider: LLMProvider
  private let providerSettings: LLMProviderSettings?
  private let isConnected: Bool
  private let onSettingsChanged: ((LLMProviderSettings?) -> Void)?
  private let onSelectModels: (() -> Void)?

  private var enabledModelsCount: Int {
    viewModel.modelsAvailable(for: provider)
      .filter { model in enabledModels.contains(model.modelInfo.id) }
      .count
  }

  private func loadCurrentSettings() {
    apiKey = providerSettings?.apiKey ?? ""
    baseURL = providerSettings?.baseUrl ?? ""
    executable = providerSettings?.executable ?? ""
  }

  private func saveSettings() {
    guard let onSettingsChanged else { return }
    let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedExecutable = executable.trimmingCharacters(in: .whitespacesAndNewlines)

    if provider.externalAgent == nil {
      guard !trimmedAPIKey.isEmpty else {
        onSettingsChanged(nil)
        return
      }
    } else {
      guard !trimmedExecutable.isEmpty else {
        onSettingsChanged(nil)
        return
      }
    }

    let providerSettings = LLMProviderSettings(
      apiKey: trimmedAPIKey,
      baseUrl: trimmedBaseURL.isEmpty ? nil : trimmedBaseURL,
      executable: trimmedExecutable.isEmpty ? nil : trimmedExecutable,
      createdOrder: -1)
    onSettingsChanged(providerSettings)

    if let externalAgent = provider.externalAgent, !trimmedExecutable.isEmpty {
      externalAgent.markHasBeenEnabledOnce()
    }
  }
}

// MARK: - APIProvider Extensions

extension LLMProvider {
  var description: String {
    switch self {
    case .anthropic:
      "Claude models"
    case .openAI:
      "GPT models"
    case .openRouter:
      "Multiple model providers"
    case .groq:
      "High-speed inference for open-weight LLMs"
    case .claudeCode:
      "Claude Code"
    case .gemini:
      "Gemini"
    default:
      "Unknown provider"
    }
  }

  /// Whether the provider requires an API key to function (regardless of whether one has already been provided).
  var needsAPIKey: Bool {
    externalAgent == nil
  }

  func isConnected(_ providerSettings: LLMProviderSettings?) -> Bool {
    if externalAgent != nil {
      providerSettings?.executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    } else {
      providerSettings?.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
  }
}

// MARK: - ProviderModelSelectionView

private struct ProviderModelSelectionView: View {
  init(
    viewModel: LLMSettingsViewModel,
    provider: LLMProvider,
    providerSettings: LLMProviderSettings?,
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

        ProviderCard(
          viewModel: viewModel,
          provider: provider,
          providerSettings: providerSettings,
          isConnected: true,
          enabledModels: viewModel.enabledModels,
          onSettingsChanged: nil,
          onSelectModels: nil)
      }
      .padding(.bottom, 16)

      ModelsView(viewModel: viewModel, availableModels: viewModel.modelsAvailable(for: provider).map(\.modelInfo))
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

  private let provider: LLMProvider
  private let providerSettings: LLMProviderSettings?
  private let dismiss: () -> Void
}
