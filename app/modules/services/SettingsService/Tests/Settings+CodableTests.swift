// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LLMFoundation
import SettingsServiceInterface
import SwiftTesting
import SwiftUI
import Testing

@testable import SettingsService

@Suite("Settings+Codable Tests")
struct SettingsCodableTests {

  @Test("Encode and decode basic settings")
  func testBasicSettingsEncodingDecoding() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      automaticallyCheckForUpdates: false,
      preferedProviders: [.claudeHaiku_3_5: .anthropic, .gpt: .openAI],
      llmProviderSettings: [:])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : false,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "fileEditMode": "direct I/O",
        "inactiveModels" : [],
        "userDefinedXcodeShortcuts" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-haiku-35" : "anthropic",
          "gpt-latest" : "openai"
        },
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : []
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Encode and decode settings with LLM provider settings")
  func testSettingsWithLLMProviderSettings() throws {
    let providerSettings = Settings.LLMProviderSettings(
      apiKey: "test-api-key",
      baseUrl: "https://api.example.com",
      executable: nil,
      createdOrder: 1)

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: [:],
      llmProviderSettings: [.anthropic: providerSettings])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "inactiveModels" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-api-key",
            "baseUrl" : "https://api.example.com",
            "createdOrder" : 1
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Encode and decode settings with multiple LLM providers")
  func testSettingsWithMultipleLLMProviders() throws {
    let anthropicSettings = Settings.LLMProviderSettings(
      apiKey: "anthropic-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)

    let openAISettings = Settings.LLMProviderSettings(
      apiKey: "openai-key",
      baseUrl: "https://api.openai.com",
      executable: nil,
      createdOrder: 2)

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: [.claudeHaiku_3_5: .anthropic],
      llmProviderSettings: [
        .anthropic: anthropicSettings,
        .openAI: openAISettings,
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "inactiveModels" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "anthropic-key",
            "createdOrder" : 1
          },
          "openai" : {
            "apiKey" : "openai-key",
            "baseUrl" : "https://api.openai.com",
            "createdOrder" : 2
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-haiku-35" : "anthropic"
        },
        "reasoningModels": {},
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Decode settings with missing optional fields uses defaults")
  func testDecodingWithMissingOptionalFields() throws {
    let json = """
      {
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: [:],
      llmProviderSettings: [:])

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode settings with partial data")
  func testDecodingWithPartialData() throws {
    let json = """
      {
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "gpt-latest" : "openai"
        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: true, // default
      automaticallyCheckForUpdates: true, // default
      preferedProviders: [.gpt: .openAI],
      llmProviderSettings: [:], // default,
      inactiveModels: [], // default
    )

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode settings ignores invalid LLM provider keys")
  func testDecodingIgnoresInvalidLLMProviderKeys() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "llmProviderSettings" : {
          "invalid-provider" : {
            "apiKey" : "test-key",
            "createdOrder" : 1
          },
          "anthropic" : {
            "apiKey" : "anthropic-key",
            "createdOrder" : 2
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {},
        "inactiveModels" : []
      }
      """

    let anthropicSettings = Settings.LLMProviderSettings(
      apiKey: "anthropic-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 2)

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [:],
      llmProviderSettings: [.anthropic: anthropicSettings])

    try testDecoding(expectedSettings, json)
  }

  @Test("Round-trip encoding and decoding preserves data")
  func testRoundTripEncodingDecoding() throws {
    let originalSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [.claudeHaiku_3_5: .anthropic, .gpt: .openAI],
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openRouter: Settings.LLMProviderSettings(
          apiKey: "openrouter-key",
          baseUrl: "https://openrouter.ai/api/v1",
          executable: nil,
          createdOrder: 3),
      ])

    let jsonData = try JSONEncoder().encode(originalSettings)
    let decodedSettings = try JSONDecoder().decode(Settings.self, from: jsonData)

    #expect(originalSettings == decodedSettings)
  }

  @Test("Encoding handles empty LLM provider settings")
  func testEncodingEmptyLLMProviderSettings() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: [:],
      llmProviderSettings: [:])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncoding(settings, json)
  }

  @Test("Encode and decode settings with reasoning models")
  func testSettingsReasoningModels() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: [.claudeHaiku_3_5: .anthropic],
      reasoningModels: [
        .claudeOpus: .init(isEnabled: true),
        .gpt: .init(isEnabled: false),
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-haiku-35" : "anthropic"
        },
        "reasoningModels" : {
          "claude-opus-4" : {
            "isEnabled" : true
          },
          "gpt-latest" : {
            "isEnabled" : false
          }
        },
        "toolPreferences": [],
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Decoding with null baseUrl works correctly")
  func testDecodingWithNullBaseUrl() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-key",
            "baseUrl" : null,
            "createdOrder" : 1
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {

        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      preferedProviders: [:],
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(
          apiKey: "test-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
      ])

    try testDecoding(expectedSettings, json)
  }

  @Test("Decoding large settings data")
  func testDecodingLargeSettingsData() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "anthropic-very-long-api-key-for-testing-purposes",
            "baseUrl" : "https://api.anthropic.com/v1/messages",
            "createdOrder" : 1
          },
          "openai" : {
            "apiKey" : "openai-very-long-api-key-for-testing-purposes",
            "baseUrl" : "https://api.openai.com/v1/chat/completions",
            "createdOrder" : 2
          },
          "openrouter" : {
            "apiKey" : "openrouter-very-long-api-key-for-testing-purposes",
            "baseUrl" : "https://openrouter.ai/api/v1",
            "createdOrder" : 3
          }
        },
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-sonnet-4" : "anthropic",
          "gpt-latest" : "openai",
          "gpt-mini-latest" : "openai",
          "claude-haiku-35" : "anthropic"
        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [
        .claudeSonnet: .anthropic,
        .gpt: .openAI,
        .gpt_mini: .openAI,
        .claudeHaiku_3_5: .anthropic,
      ],
      llmProviderSettings: [
        .anthropic: Settings.LLMProviderSettings(
          apiKey: "anthropic-very-long-api-key-for-testing-purposes",
          baseUrl: "https://api.anthropic.com/v1/messages",
          executable: nil,
          createdOrder: 1),
        .openAI: Settings.LLMProviderSettings(
          apiKey: "openai-very-long-api-key-for-testing-purposes",
          baseUrl: "https://api.openai.com/v1/chat/completions",
          executable: nil,
          createdOrder: 2),
        .openRouter: Settings.LLMProviderSettings(
          apiKey: "openrouter-very-long-api-key-for-testing-purposes",
          baseUrl: "https://openrouter.ai/api/v1",
          executable: nil,
          createdOrder: 3),
      ])

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode automaticallyCheckForUpdates setting with custom value")
  func testAutomaticallyCheckForUpdatesDecoding() throws {
    let json = """
      {
        "automaticallyCheckForUpdates" : false
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false, // default
      allowAnonymousAnalytics: true, // default
      automaticallyCheckForUpdates: false,
      preferedProviders: [:], // default
      llmProviderSettings: [:]) // default

    try testDecoding(expectedSettings, json)
  }

  @Test("Encode automaticallyCheckForUpdates setting")
  func testAutomaticallyCheckForUpdatesEncoding() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: false,
      preferedProviders: [:],
      llmProviderSettings: [:])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : false,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "toolPreferences" : [],
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncoding(settings, json)
  }

  @Test("Encode and decode settings with custom instructions")
  func testSettingsWithCustomInstructions() throws {
    let customInstructions = Settings.CustomInstructions(
      askModePrompt: "Always be concise and helpful",
      agentModePrompt: "Focus on code quality and best practices")

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [.claudeHaiku_3_5: .anthropic],
      llmProviderSettings: [:],
      customInstructions: customInstructions)

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "toolPreferences" : [],
        "customInstructions" : {
          "agentMode" : "Focus on code quality and best practices",
          "askMode" : "Always be concise and helpful"
        },
        "keyboardShortcuts" : {},
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-haiku-35" : "anthropic"
        },
        "reasoningModels": {},
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Decode settings with only askMode custom instruction")
  func testSettingsWithOnlyAskModeCustomInstruction() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "customInstructions" : {
          "askMode" : "Be brief and direct"
        },
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {}
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      preferedProviders: [:],
      llmProviderSettings: [:],
      customInstructions: Settings.CustomInstructions(askModePrompt: "Be brief and direct", agentModePrompt: nil))

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode settings with only agentMode custom instruction")
  func testSettingsWithOnlyAgentModeCustomInstruction() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "customInstructions" : {
          "agentMode" : "Prioritize performance and efficiency"
        },
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "gpt-latest" : "openai"
        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [.gpt: .openAI],
      llmProviderSettings: [:],
      customInstructions: Settings.CustomInstructions(
        askModePrompt: nil,
        agentModePrompt: "Prioritize performance and efficiency"))

    try testDecoding(expectedSettings, json)
  }

  @Test("Encode and decode settings with tool preferences")
  func testSettingsWithToolPreferences() throws {
    let toolPreferences = [
      Settings.ToolPreference(toolName: "EditFilesTool", alwaysApprove: true),
      Settings.ToolPreference(toolName: "ExecuteCommandTool", alwaysApprove: false),
      Settings.ToolPreference(toolName: "ReadFileTool", alwaysApprove: true),
    ]

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [.claudeHaiku_3_5: .anthropic],
      llmProviderSettings: [:],
      toolPreferences: toolPreferences)

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {},
        "inactiveModels" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "claude-haiku-35" : "anthropic"
        },
        "reasoningModels": {},
        "toolPreferences" : [
          {
            "alwaysApprove" : true,
            "toolName" : "EditFilesTool"
          },
          {
            "alwaysApprove" : false,
            "toolName" : "ExecuteCommandTool"
          },
          {
            "alwaysApprove" : true,
            "toolName" : "ReadFileTool"
          }
        ],
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O" 
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Decode settings with empty tool preferences")
  func testDecodingEmptyToolPreferences() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "toolPreferences" : []
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      preferedProviders: [:],
      llmProviderSettings: [:],
      toolPreferences: [])

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode settings with single tool preference")
  func testDecodingSingleToolPreference() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "toolPreferences" : [
          {
            "alwaysApprove" : true,
            "toolName" : "BuildTool"
          }
        ]
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [:],
      llmProviderSettings: [:],
      toolPreferences: [
        Settings.ToolPreference(toolName: "BuildTool", alwaysApprove: true),
      ])

    try testDecoding(expectedSettings, json)
  }

  @Test("Round-trip with tool preferences preserves data")
  func testRoundTripWithToolPreferences() throws {
    let originalSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: [.gpt: .openAI],
      llmProviderSettings: [
        .openAI: Settings.LLMProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
      ],
      customInstructions: Settings.CustomInstructions(
        askModePrompt: "Be concise",
        agentModePrompt: nil),
      toolPreferences: [
        Settings.ToolPreference(toolName: "LSTool", alwaysApprove: true),
        Settings.ToolPreference(toolName: "SearchFilesTool", alwaysApprove: false),
      ])

    let jsonData = try JSONEncoder().encode(originalSettings)
    let decodedSettings = try JSONDecoder().decode(Settings.self, from: jsonData)

    #expect(originalSettings == decodedSettings)
  }

  @Test("Decode settings without toolPreferences field uses empty array")
  func testDecodingMissingToolPreferences() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "pointReleaseXcodeExtensionToDebugApp" : false
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      preferedProviders: [:],
      llmProviderSettings: [:],
      toolPreferences: []) // Should default to empty array

    try testDecoding(expectedSettings, json)
  }

  @Test("Encode and decode keyboard shortcuts")
  func testKeyboardShortcutsEncodingDecoding() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      keyboardShortcuts: [
        .addContextToCurrentChat: .init(key: .leftArrow, modifiers: [.command, .shift]),
        .addContextToNewChat: .init(key: .init("L"), modifiers: [.command, .shift, .control]),
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "customInstructions" : {},
        "keyboardShortcuts" : {
          "addContextToCurrentChat" : {
            "key" : "",
            "modifiers" : [
              "command",
              "shift"
            ]
          },
          "addContextToNewChat" : {
            "key" : "L",
            "modifiers" : [
              "command",
              "shift",
              "control"
            ]
          },
        },
        "fileEditMode": "direct I/O",
        "inactiveModels" : [],
        "userDefinedXcodeShortcuts" : [],
        "llmProviderSettings" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {},
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : []
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Resilient decoding with corrupted field falls back to defaults")
  func testResilientDecodingWithCorruptedField() throws {
    let json = """
      {
        "allowAnonymousAnalytics" : "invalid-boolean-value",
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : "invalid-dictionary",
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-key",
            "createdOrder" : 1
          }
        }
      }
      """

    let decodedSettings = try JSONDecoder().decode(Settings.self, from: json.data(using: .utf8)!)

    // Should use defaults for corrupted fields
    #expect(decodedSettings.allowAnonymousAnalytics == true) // default value
    #expect(decodedSettings.pointReleaseXcodeExtensionToDebugApp == true) // correctly decoded
    #expect(decodedSettings.preferedProviders.isEmpty) // default empty dictionary
    #expect(decodedSettings.llmProviderSettings.count == 1) // successfully decoded valid provider
    #expect(decodedSettings.llmProviderSettings[.anthropic]?.apiKey == "test-key")
  }
}
