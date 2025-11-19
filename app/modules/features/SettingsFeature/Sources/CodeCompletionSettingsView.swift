// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionServiceInterface
import Dependencies
import DLS
import GithubCopilotFeatureInterface
import LLMFoundation
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI

// MARK: - CodeCompletionSettingsView

struct CodeCompletionSettingsView: View {
  @Binding var enableCodeCompletion: Bool
  @Binding var codeCompletionDebounceMs: Int
  @Binding var multiLineCodeCompletionDisplayMode: MultiLineCodeCompletionDisplayMode
  @Binding var codeCompletionProviderId: String?
  @Bindable var llmSettingsViewModel: LLMSettingsViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Code Completion Settings Section
        VStack(spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Autocomplete")
                .font(.title2)
            }
            Spacer()
            Toggle("", isOn: $enableCodeCompletion)
              .toggleStyle(.switch)
          }

          // Debounce Setting
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text("Debounce (ms)")
              Spacer()

              VStack {
                TextField("Debounce (ms)", text: $debounceInputText)
                  .textFieldStyle(.roundedBorder)
                  .fixedSize()
                  .onChange(of: debounceInputText) { _, newValue in
                    validateAndUpdateDebounce(newValue)
                  }
                  .onAppear {
                    debounceInputText = "\(codeCompletionDebounceMs)"
                  }
                  .onChange(of: codeCompletionDebounceMs) { _, newValue in
                    if debounceInputText != "\(newValue)" {
                      debounceInputText = "\(newValue)"
                    }
                  }
                if isInvalidInput {
                  Text("Invalid integer")
                    .font(.caption)
                    .foregroundColor(.red)
                }
              }
            }
            Text("Time to trigger an autocomplete request after a change")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .disabledOverlay(isDisabled: !enableCodeCompletion)

          // Multi-line Display Mode Setting
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              VStack(alignment: .leading) {
                Text("Multi-line display")
                Text("How multi-line completions should be shown in the editor")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()

              HoveredButton(
                action: {
                  isSelectingDisplayMode.toggle()
                },
                onHoverColor: colorScheme.tertiarySystemBackground,
                backgroundColor: colorScheme.secondarySystemBackground,
                padding: 4,
                cornerRadius: 6,
                isEnable: true)
              {
                HStack {
                  VStack(alignment: .leading) {
                    Text(multiLineCodeCompletionDisplayMode.displayName)
                  }
                  IconButton(action: { }, systemName: isSelectingDisplayMode ? "chevron.down" : "chevron.right")
                    .frame(square: 12)
                }
              }
            }
            if isSelectingDisplayMode {
              ForEach(MultiLineCodeCompletionDisplayMode.allCases, id: \.self) { mode in
                HStack(alignment: .top, spacing: 8) {
                  RadioButton(
                    isSelected: multiLineCodeCompletionDisplayMode == mode,
                    action: {
                      multiLineCodeCompletionDisplayMode = mode
                    })
                    .frame(square: 20)

                  VStack(alignment: .leading) {
                    Text(mode.displayName)
                    Text(mode.description)
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
                .tappableTransparentBackground()
                .onTapGesture {
                  multiLineCodeCompletionDisplayMode = mode
                }
              }
            }
          }
          .frame(maxWidth: .infinity)
          .disabledOverlay(isDisabled: !enableCodeCompletion)

          // Provider
          CodeCompletionProviderSection(
            codeCompletionProviderId: $codeCompletionProviderId,
            llmSettingsViewModel: llmSettingsViewModel)
            .frame(maxWidth: .infinity)
            .disabledOverlay(isDisabled: !enableCodeCompletion)
        }
        .padding(16)
        .with(cornerRadius: 8, backgroundColor: Color(NSColor.controlBackgroundColor), borderColor: Color.gray.opacity(0.2))
      }

      Spacer()
    }
  }

  @State private var debounceInputText = ""
  @State private var isInvalidInput = false
  @State private var isSelectingDisplayMode = false

  @Environment(\.colorScheme) private var colorScheme

  private func validateAndUpdateDebounce(_ value: String) {
    if let intValue = Int(value), intValue >= 0 {
      isInvalidInput = false
      codeCompletionDebounceMs = intValue
    } else if value.isEmpty {
      isInvalidInput = false
    } else {
      isInvalidInput = true
    }
  }
}

// MARK: - CodeCompletionProviderSection

private struct CodeCompletionProviderSection: View {
  @Dependency(\.codeCompletionProviders) private var codeCompletionProviders
  @State private var isSelecting = false
  @Binding var codeCompletionProviderId: String?
  @Bindable var llmSettingsViewModel: LLMSettingsViewModel

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    // Selected provider
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading) {
          Text("Provider")
          Text("The AI provider for autocompletion")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()

        HoveredButton(
          action: {
            isSelecting.toggle()
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 4,
          cornerRadius: 6)
        {
          HStack {
            if let selectedProvider {
              HStack {
                Text(selectedProvider.displayName)
                Spacer(minLength: 0)
                Circle()
                  .fill(selectedProvider.isAvailable ? .green : .red)
                  .frame(width: 8, height: 8)
              }
              //                      }
            } else {
              Text("Select")
            }
            IconButton(action: { }, systemName: isSelecting ? "chevron.down" : "chevron.right")
              .frame(square: 12)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Exanded selection
      if isSelecting {
        ForEach(codeCompletionProviders.enumerated(), id: \.offset) { _, provider in
          VStack(alignment: .leading) {
            if provider.id == "github-copilot" {
              AnyView(router.embed(route: GithubCopilotRoute()))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let aiProvider = self.provider(id: provider.id) {
              AIProviderView(
                viewModel: llmSettingsViewModel,
                provider: aiProvider,
                providerSettings: llmSettingsViewModel.providerSettings[aiProvider],
                isConnected: aiProvider.isConnected(llmSettingsViewModel.providerSettings[aiProvider]),
                enabledModels: llmSettingsViewModel.enabledModels,
                onSettingsChanged: { newSettings in
                  updateProviderSettings(for: aiProvider, with: newSettings)
                },
                onSelectModels: nil,
                frameless: true)
            }
            HoveredButton(
              action: {
                codeCompletionProviderId = provider.id
              },
              onHoverColor: colorScheme.tertiarySystemBackground,
              backgroundColor: colorScheme.secondarySystemBackground,
              padding: 4,
              cornerRadius: 6)
            {
              Text("Select")
                .frame(maxWidth: .infinity)
            }
          }
          .padding(8)
          .with(
            cornerRadius: 6,
            backgroundColor: colorScheme.secondarySystemBackground.mix(with: colorScheme.primaryBackground, by: 0.90),
            borderColor: provider.id == codeCompletionProviderId ? colorScheme.textAreaBorderColor : .clear)
        }
      }
    }
  }

  private func updateProviderSettings(for provider: AIProvider, with newSettings: AIProviderSettings?) {
    // Add new settings if provided
    if let newSettings {
      let createdOrder = llmSettingsViewModel.providerSettings[provider]?.createdOrder ?? llmSettingsViewModel.providerSettings
        .nextCreatedOrder
      let providerSettings = AIProviderSettings(
        apiKey: newSettings.apiKey,
        baseUrl: newSettings.baseUrl,
        executable: newSettings.executable,
        createdOrder: createdOrder)
      llmSettingsViewModel.save(providerSettings: providerSettings, for: provider)
    } else {
      // Remove existing settings for this provider
      llmSettingsViewModel.remove(provider: provider)
    }
  }

  private func provider(id: String) -> AIProvider? {
    AIProvider.allCases.first(where: { $0.id == id })
  }

  private var selectedProvider: CodeCompletionProvider? {
    guard let providerID = codeCompletionProviderId else { return nil }
    return codeCompletionProviders.first(where: { $0.id == providerID })
  }

  @Environment(Router.self) private var router
}
