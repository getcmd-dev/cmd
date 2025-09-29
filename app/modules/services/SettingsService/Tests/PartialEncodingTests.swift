// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationInterfaces
import SwiftTesting
import System
import Testing
@testable import SettingsService

@Suite("Partial encoding")
struct PartialEncodingTests {
  struct EncodableTests {
    @Test
    func test_partialEncoding_doesNotEncodeDefaultValues() throws {
      let settings = ExternalSettings()

      let json = """
        {}
        """

      let encoder = JSONEncoder()
      encoder.userInfo[.doNotEncodeDefaultValues] = true
      try testEncoding(settings, json, encoder: encoder)
    }

    @Test
    func test_partialEncoding_encodeNonDefaultValues() throws {
      let settings = ExternalSettings(allowAnonymousAnalytics: false)

      let json = """
        {
          "allowAnonymousAnalytics": false
        }
        """

      let encoder = JSONEncoder()
      encoder.userInfo[.doNotEncodeDefaultValues] = true
      try testEncoding(settings, json, encoder: encoder)
    }
  }

  struct WriteNonDefaultValuesTests {
    @Test
    func test_writeNonDefaultValues_writesOnlyNonDefaultValues_whenNoFileExisted() async throws {
      let settings = ExternalSettings(allowAnonymousAnalytics: false)
      let fileManager = MockFileManager()
      let fileURL = URL(filePath: "/path/to/settings.json")
      try settings.writeNonDefaultValues(to: fileURL, fileManager: fileManager)
      let file = try #require(fileManager.files.first)
      #expect(file.key.standardized.path == "/path/to/settings.json")
      file.value.expectToMatch("""
        {
            "allowAnonymousAnalytics": false
        }
        """)
    }

    @Test
    func test_writeDefaultValuesWhoseKeysAlreadyExisted() async throws {
      let settings = ExternalSettings(allowAnonymousAnalytics: false)
      let fileURL = URL(filePath: "/path/to/settings.json")
      let fileManager = MockFileManager(files: [
        fileURL.path: """
          {
              "automaticallyCheckForUpdates": false
          }
          """,
      ])
      try settings.writeNonDefaultValues(to: fileURL, fileManager: fileManager)
      let file = try #require(fileManager.files.first)
      #expect(file.key.standardized.path == "/path/to/settings.json")
      file.value.expectToMatch("""
        {
            "allowAnonymousAnalytics": false,
            "automaticallyCheckForUpdates": true
        }
        """)
    }

    @Test
    func test_keepsNonOverlappingExistingValues() async throws {
      let settings = ExternalSettings(allowAnonymousAnalytics: false)
      let fileURL = URL(filePath: "/path/to/settings.json")
      let fileManager = MockFileManager(files: [
        fileURL.path: """
          {
              "someUnknownProperty": 1
          }
          """,
      ])
      try settings.writeNonDefaultValues(to: fileURL, fileManager: fileManager)
      let file = try #require(fileManager.files.first)
      #expect(file.key.standardized.path == "/path/to/settings.json")
      file.value.expectToMatch("""
        {
            "allowAnonymousAnalytics": false,
            "someUnknownProperty": 1
        }
        """)
    }
  }
}
