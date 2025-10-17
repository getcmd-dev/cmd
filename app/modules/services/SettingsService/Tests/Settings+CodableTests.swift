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
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic, .gpt: .openAI]),
      llmProviderSettings: [
        .anthropic: .init(
          apiKey: "test-anthropic-api-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
        .openAI: .init(
          apiKey: "test-openai-api-key",
          baseUrl: "https://api.openai.com",
          executable: nil,
          createdOrder: 2),
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : false,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "fileEditMode": "direct I/O",
        "enabledModels" : [],
        "userDefinedXcodeShortcuts" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-anthropic-api-key",
            "baseUrl" : "https://api.anthropic.com",
            "createdOrder" : 1
          },
          "openai" : {
            "apiKey" : "test-openai-api-key",
            "baseUrl" : "https://api.openai.com",
            "createdOrder" : 2
          }
        },
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "anthropic/claude-3.5-haiku" : "anthropic",
          "openai/gpt-5" : "openai"
        },
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : []
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Encode and decode settings with LLM provider settings")
  func testSettingsWithAIProviderSettings() throws {
    let providerSettings = Settings.AIProviderSettings(
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
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "enabledModels" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-api-key",
            "baseUrl" : "https://api.example.com",
            "createdOrder" : 1
          }
        },
        "mcpServers" : {},
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
  func testSettingsWithMultipleAIProviders() throws {
    let anthropicSettings = Settings.AIProviderSettings(
      apiKey: "anthropic-key",
      baseUrl: nil,
      executable: nil,
      createdOrder: 1)

    let openAISettings = Settings.AIProviderSettings(
      apiKey: "openai-key",
      baseUrl: "https://api.openai.com",
      executable: nil,
      createdOrder: 2)

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: true,
      automaticallyCheckForUpdates: true,
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic]),
      llmProviderSettings: [
        .anthropic: anthropicSettings,
        .openAI: openAISettings,
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "enabledModels" : [],
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
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "anthropic/claude-3.5-haiku" : "anthropic"
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
        "llmProviderSettings" : {
          "openai" : {
            "apiKey" : "test-openai-api-key",
            "baseUrl" : "https://api.openai.com",
            "createdOrder" : 1
          }
        },
        "preferedProviders" : {
          "openai/gpt-5" : "openai"
        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: true, // default
      automaticallyCheckForUpdates: true, // default
      preferedProviders: .init([.gpt: .openAI]),
      llmProviderSettings: [
        .openAI: .init(
          apiKey: "test-openai-api-key",
          baseUrl: "https://api.openai.com",
          executable: nil,
          createdOrder: 1),
      ],
      enabledModels: [], // default
    )

    try testDecoding(expectedSettings, json)
  }

  @Test("Decode settings ignores invalid LLM provider keys")
  func testDecodingIgnoresInvalidAIProviderKeys() throws {
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

    let anthropicSettings = Settings.AIProviderSettings(
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
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic, .gpt: .openAI]),
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(
          apiKey: "anthropic-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: Settings.AIProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
        .openRouter: Settings.AIProviderSettings(
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
  func testEncodingEmptyAIProviderSettings() throws {
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
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "toolPreferences" : [],
        "enabledModels" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
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
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic]),
      llmProviderSettings: [
        .anthropic: .init(
          apiKey: "test-anthropic-api-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ],
      reasoningModels: .init([
        .claudeOpus: .init(isEnabled: true),
        .gpt: .init(isEnabled: false),
      ]))

    let json = """
      {
        "allowAnonymousAnalytics" : true,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-anthropic-api-key",
            "baseUrl" : "https://api.anthropic.com",
            "createdOrder" : 1
          }
        },
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "anthropic/claude-3.5-haiku" : "anthropic"
        },
        "reasoningModels" : {
          "anthropic/claude-opus-4.1" : {
            "isEnabled" : true
          },
          "openai/gpt-5" : {
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
        .anthropic: Settings.AIProviderSettings(
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
          "anthropic/claude-sonnet-4.5" : "anthropic",
          "openai/gpt-5" : "openai",
          "openai/gpt-3.5-turbo" : "openai",
          "anthropic/claude-3.5-haiku" : "anthropic"
        }
      }
      """

    let expectedSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: .init([
        .claudeSonnet: .anthropic,
        .gpt: .openAI,
        .gpt_turbo: .openAI,
        .claudeHaiku_3_5: .anthropic,
      ]),
      llmProviderSettings: [
        .anthropic: Settings.AIProviderSettings(
          apiKey: "anthropic-very-long-api-key-for-testing-purposes",
          baseUrl: "https://api.anthropic.com/v1/messages",
          executable: nil,
          createdOrder: 1),
        .openAI: Settings.AIProviderSettings(
          apiKey: "openai-very-long-api-key-for-testing-purposes",
          baseUrl: "https://api.openai.com/v1/chat/completions",
          executable: nil,
          createdOrder: 2),
        .openRouter: Settings.AIProviderSettings(
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
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
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

  @Test("Encode and decode settings with tool preferences")
  func testSettingsWithToolPreferences() throws {
    let toolPreferences = [
      Settings.ToolPreference(toolReferenceId: "EditFilesTool", alwaysApprove: true),
      Settings.ToolPreference(toolReferenceId: "ExecuteCommandTool", alwaysApprove: false),
      Settings.ToolPreference(toolReferenceId: "ReadFileTool", alwaysApprove: true),
    ]

    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: .init([.claudeHaiku_3_5: .anthropic]),
      llmProviderSettings: [
        .anthropic: .init(
          apiKey: "test-anthropic-api-key",
          baseUrl: "https://api.anthropic.com",
          executable: nil,
          createdOrder: 1),
      ],
      toolPreferences: toolPreferences)

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {},
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {
          "anthropic" : {
            "apiKey" : "test-anthropic-api-key",
            "baseUrl" : "https://api.anthropic.com",
            "createdOrder" : 1
          }
        },
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : true,
        "preferedProviders" : {
          "anthropic/claude-3.5-haiku" : "anthropic"
        },
        "reasoningModels": {},
        "toolPreferences" : [
          {
            "alwaysApprove" : true,
            "toolId" : "EditFilesTool"
          },
          {
            "alwaysApprove" : false,
            "toolId" : "ExecuteCommandTool"
          },
          {
            "alwaysApprove" : true,
            "toolId" : "ReadFileTool"
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
        Settings.ToolPreference(toolReferenceId: "BuildTool", alwaysApprove: true),
      ])

    try testDecoding(expectedSettings, json)
  }

  @Test("Round-trip with tool preferences preserves data")
  func testRoundTripWithToolPreferences() throws {
    let originalSettings = Settings(
      pointReleaseXcodeExtensionToDebugApp: true,
      allowAnonymousAnalytics: false,
      preferedProviders: .init([.gpt: .openAI]),
      llmProviderSettings: [
        .openAI: Settings.AIProviderSettings(
          apiKey: "openai-key",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
      ],
      toolPreferences: [
        Settings.ToolPreference(toolReferenceId: "LSTool", alwaysApprove: true),
        Settings.ToolPreference(toolReferenceId: "SearchFilesTool", alwaysApprove: false),
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
        "chatModeConfigurations" : {},
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
        "enabledModels" : [],
        "userDefinedXcodeShortcuts" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
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

  // MARK: - Chat Mode Configuration Tests

  @Test("Encode and decode chat mode configurations with nil availableToolIds")
  func testChatModeConfigurationWithNilToolIds() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      chatModeConfigurations: [
        "agent": Settings.ChatModeConfiguration(
          customInstructions: "Agent instructions",
          availableToolIds: nil), // nil means use defaults
        "ask": Settings.ChatModeConfiguration(
          customInstructions: nil,
          availableToolIds: nil),
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {
          "agent" : {
            "customInstructions" : "Agent instructions"
          },
          "ask" : {}
        },
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O"
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Encode and decode chat mode configurations with explicit availableToolIds")
  func testChatModeConfigurationWithExplicitToolIds() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      chatModeConfigurations: [
        "agent": Settings.ChatModeConfiguration(
          customInstructions: "Agent instructions",
          availableToolIds: ["edit", "glob", "search"]),
        "ask": Settings.ChatModeConfiguration(
          customInstructions: nil,
          availableToolIds: ["search", "web_search"]),
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {
          "agent" : {
            "customInstructions" : "Agent instructions",
            "tools" : ["edit", "glob", "search"]
          },
          "ask" : {
            "tools" : ["search", "web_search"]
          }
        },
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O"
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Encode and decode chat mode configurations with empty availableToolIds array")
  func testChatModeConfigurationWithEmptyToolIds() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      chatModeConfigurations: [
        "agent": Settings.ChatModeConfiguration(
          customInstructions: "No tools available",
          availableToolIds: []), // empty array means explicitly no tools
      ])

    let json = """
      {
        "allowAnonymousAnalytics" : false,
        "automaticallyCheckForUpdates" : true,
        "automaticallyUpdateXcodeSettings" : false,
        "chatModeConfigurations" : {
          "agent" : {
            "customInstructions" : "No tools available",
            "tools" : []
          }
        },
        "keyboardShortcuts" : {},
        "enabledModels" : [],
        "llmProviderSettings" : {},
        "mcpServers" : {},
        "pointReleaseXcodeExtensionToDebugApp" : false,
        "preferedProviders" : {},
        "reasoningModels": {},
        "toolPreferences" : [],
        "userDefinedXcodeShortcuts" : [],
        "fileEditMode": "direct I/O"
      }
      """

    try testEncodingDecoding(settings, json)
  }

  @Test("Decode chat mode configuration without tools field defaults to nil")
  func testDecodingChatModeConfigurationMissingTools() throws {
    let json = """
      {
        "chatModeConfigurations" : {
          "agent" : {
            "customInstructions" : "Agent instructions"
          }
        }
      }
      """

    let expectedSettings = Settings(
      allowAnonymousAnalytics: true, // default
      chatModeConfigurations: [
        "agent": Settings.ChatModeConfiguration(
          customInstructions: "Agent instructions",
          availableToolIds: nil), // Should default to nil when missing
      ])

    try testDecoding(expectedSettings, json)
  }

  // MARK: - Integration Tests for Chat Mode Configuration

  @Test("Complete settings with chat modes and tool preferences")
  func testCompleteSettingsWithChatModesAndToolPreferences() throws {
    let settings = Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      allowAnonymousAnalytics: true,
      chatModeConfigurations: [
        "agent": Settings.ChatModeConfiguration(
          customInstructions: "Agent mode instructions",
          availableToolIds: nil), // Use defaults for agent
        "ask": Settings.ChatModeConfiguration(
          customInstructions: "Ask mode instructions",
          availableToolIds: ["glob", "search", "web_search"]), // Explicit tools for ask
      ],
      toolPreferences: [
        Settings.ToolPreference(toolReferenceId: "edit", alwaysApprove: true),
        Settings.ToolPreference(toolReferenceId: "bash", alwaysApprove: false),
      ])

    // Round-trip test
    let jsonData = try JSONEncoder().encode(settings)
    let decodedSettings = try JSONDecoder().decode(Settings.self, from: jsonData)

    #expect(decodedSettings == settings)
    #expect(decodedSettings.chatModeConfigurations["agent"]?.customInstructions == "Agent mode instructions")
    #expect(decodedSettings.chatModeConfigurations["agent"]?.availableToolIds == nil)
    #expect(decodedSettings.chatModeConfigurations["ask"]?.availableToolIds == ["glob", "search", "web_search"])
    #expect(decodedSettings.toolPreferences.count == 2)
  }

  @Test("ChatModeConfiguration semantics: nil vs empty vs populated")
  func testChatModeConfigurationSemantics() throws {
    // Test the three distinct states of availableToolIds
    let config1 = Settings.ChatModeConfiguration(
      customInstructions: nil,
      availableToolIds: nil) // Use defaults from tool.isAvailableByDefault(in:)

    let config2 = Settings.ChatModeConfiguration(
      customInstructions: nil,
      availableToolIds: []) // Explicitly no tools

    let config3 = Settings.ChatModeConfiguration(
      customInstructions: nil,
      availableToolIds: ["glob", "search"]) // Explicitly these tools

    // Verify they are different
    #expect(config1 != config2)
    #expect(config2 != config3)
    #expect(config1 != config3)

    // Verify they encode differently
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys

    let data1 = try encoder.encode(config1)
    let data2 = try encoder.encode(config2)
    let data3 = try encoder.encode(config3)

    let json1 = String(data: data1, encoding: .utf8)!
    let json2 = String(data: data2, encoding: .utf8)!
    let json3 = String(data: data3, encoding: .utf8)!

    // nil should not include "tools" field
    #expect(!json1.contains("tools"))

    // empty array should have "tools": []
    #expect(json2.contains("\"tools\":[]"))

    // populated array should have the tools
    #expect(json3.contains("\"tools\":[\"glob\",\"search\"]"))
  }
}
