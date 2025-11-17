// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import GithubCopilotFeatureInterface
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI

// MARK: - CodeCompletionSettingsView

struct CodeCompletionSettingsView: View {
  @Binding var enableCodeCompletion: Bool
  @Binding var codeCompletionDebounceMs: Int
  @Binding var multiLineCodeCompletionDisplayMode: MultiLineCodeCompletionDisplayMode

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
          VStack(alignment: .leading, spacing: 4) {
            Text("Provider").frame(maxWidth: .infinity, alignment: .leading)

            CodeCompletionProviderSection()
          }
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
  var body: some View {
    AnyView(router.embed(route: GithubCopilotRoute()))
  }

  @Environment(Router.self) private var router
}
