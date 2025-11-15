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
          InternalSettingsRow(
            "Enable code completion",
            value: $enableCodeCompletion)

          VStack(alignment: .leading, spacing: 4) {
            Text("Code completion debounce (ms)")
            Text("Delay after keystroke before requesting completions (10ms - 5000ms)")
              .font(.caption)
              .foregroundColor(.secondary)
            HStack {
              Text("10ms")
                .font(.caption2)
                .foregroundColor(.secondary)
              Slider(
                value: Binding(
                  get: { log10(Double(codeCompletionDebounceMs)) },
                  set: { codeCompletionDebounceMs = Int(pow(10.0, $0).rounded()) }),
                in: 1...3,
                step: 0.1)
              Text("1000ms")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Text("\(codeCompletionDebounceMs)ms")
              .font(.caption)
              .foregroundColor(.primary)
          }

          VStack(alignment: .leading, spacing: 4) {
            Text("Multi-line code completion display mode")
            Text("How multi-line code suggestions should be shown in the editor")
              .font(.caption)
              .foregroundColor(.secondary)
            Picker("Display Mode", selection: $multiLineCodeCompletionDisplayMode) {
              ForEach(MultiLineCodeCompletionDisplayMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
            .pickerStyle(.menu)
            .padding(.top, 14)
            .padding(.bottom, 4)
          }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1))

        // Provider Section
        VStack(alignment: .leading, spacing: 12) {
          Text("Provider")
            .font(.headline)
            .padding(.horizontal, 4)

          CodeCompletionProviderRow()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1))
      }

      Spacer()
    }
  }

  @Environment(\.colorScheme) private var colorScheme
}

// MARK: - CodeCompletionProviderRow

private struct CodeCompletionProviderRow: View {
  var body: some View {
    AnyView(router.embed(route: GithubCopilotRoute()))
  }

  @Environment(Router.self) private var router
}
