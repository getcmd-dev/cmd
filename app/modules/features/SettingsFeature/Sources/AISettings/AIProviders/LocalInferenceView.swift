// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import LLMFoundation
import SwiftUI

// MARK: - LocalInferenceView

struct LocalInferenceView: View {
  /// Initializes the card with the local inference configuration and a binding to its executable path.
  init(
    localInference: LocalInference,
    baseURL: Binding<String>,
    executable: Binding<String>)
  {
    provider = localInference.llmProvider
    self.localInference = localInference
    _baseURL = baseURL
    _executable = executable
    _executableFinder = .init(initialValue: ExecutableFinder(executable: localInference.executableName))
  }

  /// The local inference configuration.
  let localInference: LocalInference

  /// The AI provider associated with this local inference.
  let provider: AIProvider

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let executablePath = executableFinder.executablePath {
        HStack {
          Text("\(provider.name)'s executable was found")
            .fontWeight(.medium)

          Spacer()

          HoveredButton(
            action: {
              executable = executable.isEmpty ? executablePath : ""
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 5,
            content: {
              Text(executable.isEmpty ? "Enable" : "Disable")
            })
        }
      } else if baseURL.isEmpty {
        Text("\(provider.name)'s executable could not be found. Either:")
          .font(.subheadline)
          .fontWeight(.medium)
        PlainLink("install it first", destination: localInference.installationInstructions)
          .font(.subheadline)
          .fontWeight(.medium)
        Text("or configure a custom base URL below:")
          .font(.subheadline)
          .fontWeight(.medium)
      }

      let showTitle = executableFinder.executablePath != nil || !baseURL.isEmpty
      if showTitle {
        Text("Base URL")
          .font(.subheadline)
          .fontWeight(.medium)
      }
      TextField(localInference.defaultBaseUrl.absoluteString, text: $baseURL)
        .textFieldStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .with(
          cornerRadius: 6,
          backgroundColor: Color(
            NSColor.textBackgroundColor),
          borderColor: Color.gray.opacity(0.3))

      Text("Leave empty to use default")
        .font(.footnote)
        .foregroundColor(.secondary)
    }
  }

  /// Binding to the executable path or launch command.
  @Binding private var executable: String

  /// Binding to the base URL.
  @Binding private var baseURL: String

  /// Helper to locate the executable on disk.
  @State private var executableFinder: ExecutableFinder

  @Environment(\.colorScheme) private var colorScheme
}
