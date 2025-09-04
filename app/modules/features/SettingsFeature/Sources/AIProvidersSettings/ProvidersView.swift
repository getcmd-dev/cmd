// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import LLMFoundation
import SettingsServiceInterface
import ShellServiceInterface
import SwiftUI

// MARK: - ProvidersView

public struct ProvidersView: View {
  public init(providerSettings: Binding<AllLLMProviderSettings>) {
    _providerSettings = providerSettings
  }

  public var body: some View {
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
              provider: providerInfo.provider,
              settings: providerInfo.settings,
              isConnected: providerInfo.isConnected,
              onSettingsChanged: { newSettings in
                updateProviderSettings(for: providerInfo.provider, with: newSettings)
              })
              .id(providerInfo.provider)
          }
        }
        .padding(.bottom, 20)
      }
    }
    .onAppear {
      setInitialOrder()
    }
  }

  @Binding var providerSettings: AllLLMProviderSettings

  @State private var orderedProviders: [LLMProvider] = LLMProvider.allCases

  @State private var searchText = ""

  private var filteredProviders: [ProviderInfo] {
    let allProviders = orderedProviders.map { provider in
      let existingSettings = providerSettings[provider]
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

  private func setInitialOrder() {
    orderedProviders = LLMProvider.allCases.map { provider in
      (provider, provider.isConnected(providerSettings[provider]))
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
      providerSettings[provider] = .init(
        apiKey: newSettings.apiKey,
        baseUrl: newSettings.baseUrl,
        executable: newSettings.executable,
        createdOrder: createdOrder)
    } else {
      // Remove existing settings for this provider
      providerSettings.removeValue(forKey: provider)
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
    provider: LLMProvider,
    settings: LLMProviderSettings?,
    isConnected: Bool,
    onSettingsChanged: @escaping (LLMProviderSettings?) -> Void)
  {
    self.provider = provider
    self.settings = settings
    self.isConnected = isConnected
    self.onSettingsChanged = onSettingsChanged
  }

  let provider: LLMProvider
  let settings: LLMProviderSettings?
  let isConnected: Bool
  let onSettingsChanged: (LLMProviderSettings?) -> Void

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

  @Environment(\.colorScheme) private var colorScheme

  @State private var apiKey = ""
  @State private var baseURL = ""
  @State private var executable = ""
  @State private var showAPIKey = false

  private func loadCurrentSettings() {
    apiKey = settings?.apiKey ?? ""
    baseURL = settings?.baseUrl ?? ""
    executable = settings?.executable ?? ""
  }

  private func saveSettings() {
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

    let settings = LLMProviderSettings(
      apiKey: trimmedAPIKey,
      baseUrl: trimmedBaseURL.isEmpty ? nil : trimmedBaseURL,
      executable: trimmedExecutable.isEmpty ? nil : trimmedExecutable,
      createdOrder: -1)
    onSettingsChanged(settings)

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

  func isConnected(_ settings: LLMProviderSettings?) -> Bool {
    if externalAgent != nil {
      settings?.executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    } else {
      settings?.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
  }
}
