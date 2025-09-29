// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import SettingsServiceInterface
import ShellServiceInterface
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - EmptyChatView

struct EmptyChatView: View {
  init() {
    @Dependency(\.settingsService) var settingsService
    _keyboardShortcuts = .init(initialValue: settingsService.value(for: \.keyboardShortcuts))
    @Dependency(\.xcodeObserver) var xcodeObserver
    _hasXcodeOpen = .init(initialValue: xcodeObserver.state.focusedInstance != nil)
  }

  var body: some View {
    VStack {
      if !hasXcodeOpen {
        openXcodeButton
          .padding(.top, 10)
      } else {
        Text("Keyboard Shortcuts")
          .padding(4)
        Text("Get started quickly with these helpful commands")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.bottom, 4)
        keyBoardShortCutCard(
          title: "Add to current chat",
          description: "Continue existing conversation with added context",
          keys: keyboardShortcuts[withDefault: .addContextToCurrentChat].keys)
        keyBoardShortCutCard(
          title: "Add to new chat",
          description: "Create a new conversation with the selected context",
          keys: keyboardShortcuts[withDefault: .addContextToNewChat].keys)
        keyBoardShortCutCard(
          title: "Dismiss",
          description: "Dismiss cmd. It'll still be available in the menu bar and respond to shortcuts",
          keys: keyboardShortcuts[withDefault: .dismissChat].keys)
        keyBoardShortCutCard(title: "Cycle chat mode", description: "Switch between different chat mode", keys: ["⇧", "⇥"])
      }
    }
    .onReceive(settingsService.liveValue(for: \.keyboardShortcuts), perform: { keyboardShortcuts in
      self.keyboardShortcuts = keyboardShortcuts
    })
    .onReceive(xcodeObserver.statePublisher.receive(on: DispatchQueue.main), perform: { newXcodeState in
      hasXcodeOpen = newXcodeState.focusedInstance != nil
    })
  }

  @ViewBuilder
  var openXcodeButton: some View {
    VStack {
      HoveredButton(
        action: {
          Task {
            do {
              guard
                let xcodePath = try await shellService.run("xcode-select --print-path").stdout?
                  .trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".app").first
              else {
                xcodeOpenError = "Could not find Xcode. Please ensure Xcode is installed."
                return
              }
              try await shellService.run("open \(xcodePath).app")
            } catch {
              xcodeOpenError = "Could not open Xcode: \(error.localizedDescription)"
            }
          }
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 8,
        content: {
          Text("Open Xcode")
        })
      if let xcodeOpenError {
        Text(xcodeOpenError)
          .foregroundColor(colorScheme.redError)
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  @ViewBuilder
  func keyBoardShortCutCard(title: String, description: String, keys: [String]) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer(minLength: 10)
      HStack(spacing: 0) {
        ForEach(Array(keys.enumerated()), id: \.element) { idx, key in
          Text(key)
            .font(.system(size: 12, design: .monospaced))
            .frame(square: 12)
            .padding(4)
            .with(
              cornerRadius: 4,
              backgroundColor: .gray.opacity(0.1),
              borderColor: colorScheme.textAreaBorderColor,
              borderWidth: 0.5)
          if idx != keys.count - 1 {
            Text("+")
              .padding(.horizontal, 4)
          }
        }
      }
    }
    .padding(8)
    .with(
      cornerRadius: 4,
      backgroundColor: .gray.opacity(0.02),
      borderColor: colorScheme.textAreaBorderColor,
      borderWidth: 0.5)
  }

  @State private var hasXcodeOpen: Bool
  @State private var xcodeOpenError: String?

  @State private var keyboardShortcuts: SettingsServiceInterface.Settings.KeyboardShortcuts
  @Environment(\.colorScheme) private var colorScheme

  @Dependency(\.settingsService) private var settingsService
  @Dependency(\.xcodeObserver) private var xcodeObserver
  @Dependency(\.shellService) private var shellService
}

extension SettingsServiceInterface.Settings.KeyboardShortcut {
  var keys: [String] {
    modifiers.map(\.description) + [key.description]
  }
}
