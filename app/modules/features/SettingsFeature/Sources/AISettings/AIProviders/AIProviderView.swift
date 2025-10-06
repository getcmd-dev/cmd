// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import DLS
import LLMFoundation
import SettingsServiceInterface
import SwiftUI

// MARK: - AIProviderView

struct AIProviderView: View {
  init(
    viewModel: LLMSettingsViewModel,
    provider: AIProvider,
    providerSettings: AIProviderSettings?,
    isConnected: Bool,
    enabledModels: [AIModelID],
    onSettingsChanged: ((AIProviderSettings?) -> Void)?,
    onSelectModels: (() -> Void)?)
  {
    self.viewModel = viewModel
    self.provider = provider
    self.providerSettings = providerSettings
    self.isConnected = isConnected
    self.enabledModels = enabledModels
    self.onSettingsChanged = onSettingsChanged
    self.onSelectModels = onSelectModels
    modelsAvailable = viewModel.modelsAvailable(for: provider)
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
          ExternalAgentView(externalAgent: externalAgent, executable: $executable)
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

  @Bindable private var modelsAvailable: ObservableValue<[AIProviderModel]>

  @Bindable private var viewModel: LLMSettingsViewModel
  @Environment(\.colorScheme) private var colorScheme

  @State private var apiKey = ""
  @State private var baseURL = ""
  @State private var executable = ""
  @State private var showAPIKey = false

  private let enabledModels: [AIModelID]

  private let provider: AIProvider
  private let providerSettings: AIProviderSettings?
  private let isConnected: Bool
  private let onSettingsChanged: ((AIProviderSettings?) -> Void)?
  private let onSelectModels: (() -> Void)?

  private var enabledModelsCount: Int {
    modelsAvailable.wrappedValue
      .filter { model in enabledModels.contains(model.modelInfo.id) }
      .count
  }

  private var isConfigurable: Bool {
    onSettingsChanged != nil
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

    let providerSettings = AIProviderSettings(
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

extension AIProvider {
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

  func isConnected(_ providerSettings: AIProviderSettings?) -> Bool {
    if externalAgent != nil {
      providerSettings?.executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    } else {
      providerSettings?.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
  }
}
