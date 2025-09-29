// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SettingsServiceInterface
import SwiftTesting
import Testing

@Suite("MCPServerConfigurations encoding")
struct MCPServerConfigurationsEncodingTests {
  @Test("can encode and decode MCPServerConfiguration")
  func test_canEncodeDecodeMCPServerConfigurations() throws {
    let configurations: [String: MCPServerConfiguration] = [
      "ripgrep-search": MCPServerConfiguration.stdio(.init(
        name: "ripgrep-search",
        command: "npx",
        args: ["-y", "mcp-ripgrep@latest"],
        env: ["LOGLEVEL": "debug"],
        disabled: false)),
      "http-server": MCPServerConfiguration.http(.init(
        name: "http-server",
        url: "http://localhost:8080",
        headers: ["Authorization": "Bearer token"])),
    ]
    let sut = MCPServerConfigurations(configurations: configurations)

    let json = """
      {
        "http-server" : {
          "headers" : {
            "Authorization" : "Bearer token"
          },
          "type" : "http",
          "url" : "http://localhost:8080"
        },
        "ripgrep-search" : {
          "args" : [
            "-y",
            "mcp-ripgrep@latest"
          ],
          "command" : "npx",
          "env" : {
            "LOGLEVEL" : "debug"
          },
          "type" : "stdio"
        }
      }
      """

    try testEncodingDecoding(sut, json)
  }
}
