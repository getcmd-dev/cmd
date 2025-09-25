// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import MCPServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing

@testable import MCPService

@Suite("MCPServerConfiguration Codable Tests")
struct MCPServerConfigurationCodableTests {

  @Test("Decode MCPServerConfigurations with mixed server types")
  func testMixedServerTypesDecoding() throws {
    let json = """
      {
        "database" : {
          "type" : "stdio",
          "command" : "python",
          "args" : ["db_server.py"],
          "disabled" : true
        },
        "web-api" : {
          "type" : "http",
          "url" : "https://web-api.example.com/mcp",
          "headers" : {
            "Authorization" : "Bearer abc123"
          }
        },
        "local-tools" : {
          "type" : "stdio",
          "command" : "./local-tools.sh",
          "env" : {
            "TOOLS_CONFIG" : "./config.json"
          },
          "autoApprove" : [
            "list_files"
          ]
        }
      }
      """

    let decoded = try JSONDecoder().decode(MCPServerConfigurations.self, from: json.data(using: .utf8)!)

    #expect(decoded.configurations.count == 3)

    // Verify database server (stdio, disabled)
    if case .stdio(let dbConfig) = decoded.configurations["database"] {
      #expect(dbConfig.name == "database")
      #expect(dbConfig.command == "python")
      #expect(dbConfig.args == ["db_server.py"])
      #expect(dbConfig.disabled == true)
    } else {
      Issue.record("Expected stdio configuration for database server")
    }

    // Verify web API server (http)
    if case .http(let apiConfig) = decoded.configurations["web-api"] {
      #expect(apiConfig.name == "web-api")
      #expect(apiConfig.url == "https://web-api.example.com/mcp")
      #expect(apiConfig.headers?["Authorization"] == "Bearer abc123")
      #expect(apiConfig.disabled == false)
    } else {
      Issue.record("Expected http configuration for web-api server")
    }

    // Verify local tools server (stdio with autoApprove)
    if case .stdio(let toolsConfig) = decoded.configurations["local-tools"] {
      #expect(toolsConfig.name == "local-tools")
      #expect(toolsConfig.command == "./local-tools.sh")
      #expect(toolsConfig.env?["TOOLS_CONFIG"] == "./config.json")
      #expect(toolsConfig.autoApprove == ["list_files"])
    } else {
      Issue.record("Expected stdio configuration for local-tools server")
    }
  }
}
