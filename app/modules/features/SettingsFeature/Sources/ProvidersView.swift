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
        isConnected: existingSettings?.hasValidAPIKey == true || existingSettings?.hasValidExecutable == true)
    }

    return searchText.isEmpty
      ? allProviders
      : allProviders.filter {
        $0.provider.name.localizedCaseInsensitiveContains(searchText)
      }
  }

  private func setInitialOrder() {
    orderedProviders = LLMProvider.allCases.map { provider in
      let existingSettings = providerSettings[provider]
      return (provider, existingSettings?.hasValidAPIKey == true)
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
    executableFinder = ExecutableFinder(defaultExecutable: provider.defaultExecutable)
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

          Text(provider.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }

      // API Key section
      if provider.needsAPIKey {
        VStack(alignment: .leading, spacing: 8) {
          Text("API Key")
            .font(.subheadline)
            .fontWeight(.medium)

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
      if provider.isLocal {
        VStack(alignment: .leading, spacing: 8) {
          Text("How to run \(provider.name)")
            .font(.subheadline)
            .fontWeight(.medium)

          // keep the default executable name if it can be found, as there is no need to hardcode a specivic path.
          TextField(
            executableFinder.executablePath != nil
              ? "\(provider.defaultExecutable ?? "executable")"
              : "/path/to/\(provider.defaultExecutable ?? "executable")",
            text: $executable)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.3))
        }
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

  @Bindable private var executableFinder: ExecutableFinder

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

    guard !trimmedAPIKey.isEmpty || !trimmedExecutable.isEmpty else {
      onSettingsChanged(nil)
      return
    }

    let settings = LLMProviderSettings(
      apiKey: trimmedAPIKey,
      baseUrl: trimmedBaseURL.isEmpty ? nil : trimmedBaseURL,
      executable: trimmedExecutable.isEmpty ? nil : trimmedExecutable,
      createdOrder: -1)
    onSettingsChanged(settings)
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
    case .claudeCode:
      "Claude Code"
    default:
      "Unknown provider"
    }
  }

  var needsAPIKey: Bool {
    switch self {
    case .claudeCode:
      false
    default:
      true
    }
  }

  var isLocal: Bool {
    switch self {
    case .claudeCode:
      true
    default:
      false
    }
  }

  var defaultExecutable: String? {
    switch self {
    case .claudeCode:
      "claude"
    default:
      nil
    }
  }
}

// MARK: - ProviderSettings Extensions

extension LLMProviderSettings {

  var hasValidAPIKey: Bool {
    !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var hasValidExecutable: Bool {
    executable?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }
}

@MainActor @Observable
private final class ExecutableFinder {
  init(defaultExecutable: String?) {
    self.defaultExecutable = defaultExecutable
    if let defaultExecutable {
      Task {
        let executablePath = try await shellService.run("which \(defaultExecutable)", useInteractiveShell: true)
        Task { @MainActor [weak self] in
          self?.executablePath = executablePath.stdout?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
    }
  }

  private(set) var executablePath: String?

  private let defaultExecutable: String?
  @ObservationIgnored
  @Dependency(\.shellService) private var shellService
}
