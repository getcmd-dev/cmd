// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import LLMFoundation
import ShellServiceInterface
import SwiftUI

// MARK: - ExternalAgentView

/// Represents an external agent card for configuring third-party agents that handle their own agentic behavior, such as Claude Code.
struct ExternalAgentView: View {

  /// Initializes the card with the external agent configuration and a binding to its executable path.
  init(
    externalAgent: ExternalAgent,
    executable: Binding<String>)
  {
    provider = externalAgent.llmProvider
    self.externalAgent = externalAgent
    _executable = executable
    _executableFinder = .init(initialValue: ExecutableFinder(defaultExecutable: externalAgent.defaultExecutableName))
  }

  /// The external agent configuration.
  let externalAgent: ExternalAgent

  /// The AI provider associated with this external agent.
  let provider: AIProvider

  /// Returns the executable path if set, or nil if empty.
  var executablePath: String? {
    executable.isEmpty ? nil : executable
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let executablePath {
        HStack {
          HoveredButton(
            action: {
              executable = ""
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 5,
            content: {
              Text("Disable")
            })
        }
        Text("Change launch options (you can set specific arguments, or a custom path below)")
          .fontWeight(.medium)

        TextField(
          executablePath,
          text: $executable)
          .textFieldStyle(.plain)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(NSColor.textBackgroundColor))
          .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.3))
      } else if let executablePath = executableFinder.executablePath {
        HStack {
          Text("\(provider.name)'s executable was found at \(executablePath)")
            .textSelection(.enabled)
            .fontWeight(.medium)

          Spacer()

          HoveredButton(
            action: {
              executable = executablePath
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 5,
            content: {
              Text("Enable")
            })
        }
      } else {
        Text("\(provider.name)'s executable could not be found. Either:")
          .font(.subheadline)
          .fontWeight(.medium)
        PlainLink("install it first", destination: externalAgent.installationInstructions)
          .font(.subheadline)
          .fontWeight(.medium)
        Text("or if it's already installed describe how to launch it below:")
          .font(.subheadline)
          .fontWeight(.medium)

        TextField(
          executableFinder.executablePath != nil
            ? "\(externalAgent.defaultExecutableName)"
            :
            "(e.g. '/path/to/\(provider.name.lowercased().replacingOccurrences(of: " ", with: "-")) --some-arg')",
          text: $executable)
          .textFieldStyle(.plain)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(NSColor.textBackgroundColor))
          .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.3))
      }
    }.onChange(of: executableFinder.executablePath ?? "") { newValue in
      if !newValue.isEmpty, !externalAgent.hasBeenEnabledOnce {
        // When the external agent's executable is found, and it has never been enabled, it is enabled by default.
        executable = newValue
      }
    }
  }

  /// Binding to the executable path or launch command.
  @Binding private var executable: String

  /// Helper to locate the executable on disk.
  @State private var executableFinder: ExecutableFinder

  @Environment(\.colorScheme) private var colorScheme
}

// MARK: - ExecutableFinder

/// A helper that finds where a given executable is located on disk by running `which`.
@MainActor @Observable
private final class ExecutableFinder {
  /// Initializes the finder and attempts to locate the executable using `which`.
  init(defaultExecutable: String) {
    @Dependency(\.shellService) var shellService

    Task { [weak self] in
      do {
        let executablePath = try await shellService.run("which \(defaultExecutable)", useInteractiveShell: true)
        await MainActor.run {
          guard let self else { return }
          self.executablePath = executablePath.stdout?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      } catch {
        // Silently ignore errors - executable not found is expected
      }
    }
  }

  /// The path where the executable was found, or nil if not found.
  private(set) var executablePath: String?
}

extension ExternalAgent {
  /// Whether the external agent has been enabled at least once.
  /// When the agent is disabled, this value will help understand whether the agent has never been enabled, and can be enabled by default, or if it has been disabled by the user.
  var hasBeenEnabledOnce: Bool {
    @Dependency(\.userDefaults) var userDefaults
    return userDefaults.bool(forKey: hasEnabledOnceUserDefaultsKey)
  }

  /// Save the fact that the external agent has been enabled at least once.
  func markHasBeenEnabledOnce() {
    @Dependency(\.userDefaults) var userDefaults
    userDefaults.set(true, forKey: hasEnabledOnceUserDefaultsKey)
  }

  /// Unsave the fact that the external agent has been enabled at least once.
  func unmarkHasBeenEnabledOnce() {
    @Dependency(\.userDefaults) var userDefaults
    userDefaults.removeObject(forKey: hasEnabledOnceUserDefaultsKey)
  }

  private var hasEnabledOnceUserDefaultsKey: String {
    "has-enabled-\(llmProvider.id)-once"
  }
}
