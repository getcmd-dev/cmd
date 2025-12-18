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
    isConfigured: Bool,
    enabledModels: [AIModelID],
    onSettingsChanged: ((AIProviderSettings?) -> Void)?,
    onSelectModels: (() -> Void)?,
    frameless: Bool = false)
  {
    self.viewModel = viewModel
    self.provider = provider
    self.providerSettings = providerSettings
    self.isConfigured = isConfigured
    self.enabledModels = enabledModels
    self.onSettingsChanged = onSettingsChanged
    self.onSelectModels = onSelectModels
    self.frameless = frameless
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
            Text(isConfigured ? "Configured" : "Not configured")
              .font(.subheadline)
              .foregroundColor(isConfigured ? colorScheme.addedLineDiffText : .secondary)
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
            .with(cornerRadius: 6, backgroundColor: Color(NSColor.textBackgroundColor), borderColor: Color.gray.opacity(0.3))

            Text("API keys are stored securely in the keychain")
              .font(.footnote)
              .foregroundColor(.secondary)
          }
        }

        // External agent section
        if let externalAgent = provider.externalAgent {
          ExternalAgentView(externalAgent: externalAgent, executable: $executable)
        }

        // Local inference section
        if let localInference = provider.localInference {
          LocalInferenceView(localInference: localInference, baseURL: $baseURL, executable: $executable)
        }
      }

      // Models button
      if isConfigured, let onSelectModels, !provider.isExternalAgent {
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
          .with(cornerRadius: 6, backgroundColor: Color(NSColor.textBackgroundColor), borderColor: Color.gray.opacity(0.3))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(frameless ? 0 : 16)
    .with(
      cornerRadius: frameless ? nil : 12,
      backgroundColor: frameless ? nil : Color(NSColor.textBackgroundColor),
      borderColor: frameless ? nil : Color.gray.opacity(0.2))
    .onAppear {
      loadCurrentSettings()
    }
    .onChange(of: apiKey) { _, _ in
      saveSettings()
    }
    .onChange(of: baseURL) { _, _ in
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
  private let isConfigured: Bool
  private let onSettingsChanged: ((AIProviderSettings?) -> Void)?
  private let onSelectModels: (() -> Void)?
  private let frameless: Bool

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

    if provider.needsAPIKey {
      guard !trimmedAPIKey.isEmpty else {
        onSettingsChanged(nil)
        return
      }
    } else if provider.isExternalAgent {
      guard !trimmedExecutable.isEmpty else {
        onSettingsChanged(nil)
        return
      }
    } else if provider.isLocalInference {
      guard !trimmedExecutable.isEmpty || URL(string: trimmedBaseURL) != nil else {
        onSettingsChanged(nil)
        return
      }
    }

    let providerSettings = AIProviderSettings(
      apiKey: trimmedAPIKey.isEmpty ? nil : trimmedAPIKey,
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
    case .codex:
      "Codex"
    case .gemini:
      "Gemini"
    case .geminiCLI:
      "Gemini CLI"
    case .mistral:
      "Mistral"
    case .inception:
      "Inception"
    case .ollama:
      "Chat & build with open models"
    default:
      "Unknown provider"
    }
  }

  /// Whether the provider requires an API key to function (regardless of whether one has already been provided).
  var needsAPIKey: Bool {
    !isExternalAgent && !isLocalInference
  }

  func isConfigured(_ providerSettings: AIProviderSettings?) -> Bool {
    if needsAPIKey {
      return providerSettings?.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    } else if isExternalAgent {
      return providerSettings?.executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    } else if isLocalInference {
      if
        let baseUrl = providerSettings?.baseUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
        URL(string: baseUrl) != nil
      {
        return true
      }
      return providerSettings?.executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
    return false
  }
}
