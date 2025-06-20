// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFoundation
import DLS
import SettingsServiceInterface
import SwiftUI

// MARK: - ChatModeView

struct ChatModeView: View {

  @Binding var customInstructions: SettingsServiceInterface.Settings.CustomInstructions

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        askModeView
        Divider()
        agentModeView
        InformationCard(
          title: "Tips for Custom Instructions",
          tips: [
            "Keep instructions concise and specific to your needs",
            "Custom instructions are inserted into the default system prompt",
            "Use clear, actionable language rather than vague descriptions",
          ])
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.blue.opacity(0.1)))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.blue.opacity(0.2), lineWidth: 1))
        Spacer(minLength: 20)
      }
    }
  }

  private var askModeView: some View {
    CustomInstructionSection(
      text: Binding(
        get: { customInstructions.askMode ?? "" },
        set: { customInstructions.askMode = $0.isEmpty ? nil : $0 }),
      iconName: ChatMode.ask.systemImageName,
      title: "Ask Mode",
      subtitle: "Provide extra instructions for Ask Mode.")
  }

  private var agentModeView: some View {
    CustomInstructionSection(
      text: Binding(
        get: { customInstructions.agentMode ?? "" },
        set: { customInstructions.agentMode = $0.isEmpty ? nil : $0 }),
      iconName: ChatMode.agent.systemImageName,
      title: "Agent Mode",
      subtitle: "Provide extra instructions for Agent Mode.")
  }
}

// MARK: - CustomInstructionSection

struct CustomInstructionSection: View {

  init(
    text: Binding<String>,
    iconName: String,
    title: String,
    subtitle: String,
    minHeight: CGFloat = 100,
    maxHeight: CGFloat = 200,
    fontSize: CGFloat = 13)
  {
    _text = text
    self.iconName = iconName
    self.title = title
    self.subtitle = subtitle
    self.minHeight = minHeight
    self.maxHeight = maxHeight
    self.fontSize = fontSize
  }

  @Binding var text: String

  let iconName: String
  let title: String
  let subtitle: String
  let minHeight: CGFloat
  let maxHeight: CGFloat
  let fontSize: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Icon(systemName: iconName)
          .frame(width: 16, height: 16)
        Text(title)
          .font(.headline)
      }
      .foregroundColor(.primary)

      Text(subtitle)
        .font(.caption)
        .foregroundColor(.secondary)
      TextEditor(text: $text)
        .font(.system(size: fontSize))
        .scrollContentBackground(.hidden)
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1))
    }
  }
}

// MARK: - InformationCard

struct InformationCard: View {

  init(
    iconName: String = "info.circle",
    title: String,
    tips: [String],
    iconColor: Color = .blue)
  {
    self.iconName = iconName
    self.title = title
    self.tips = tips
    self.iconColor = iconColor
  }

  let iconName: String
  let title: String
  let tips: [String]
  let iconColor: Color

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Image(systemName: iconName)
        .font(.system(size: 14))
        .foregroundColor(iconColor)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .fontWeight(.medium)

        ForEach(tips, id: \.self) { tip in
          Text("• \(tip)")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Spacer()
    }
  }
}

// MARK: - Preview
#if DEBUG
#Preview {
  ChatModeView(
    customInstructions: .constant(
      SettingsServiceInterface.Settings.CustomInstructions(
        askModePrompt: "Focus on providing clear and concise answers",
        agentModePrompt: "Be proactive in suggesting improvements")))
    .frame(width: 600, height: 500)
    .padding()
}
#endif
