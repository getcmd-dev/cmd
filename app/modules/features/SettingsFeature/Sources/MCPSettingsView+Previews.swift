// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SettingsServiceInterface
import SwiftUI

#if DEBUG

private let sampleMCPServers: [String: MCPServerConfiguration] = [
  MCPServerConfiguration.http(.init(
    name: "Github",
    url: "https://github.com")),
  MCPServerConfiguration.stdio(.init(
    name: "sqlite",
    command: "sqlite",
    args: ["--init", "./sqlite/init.sql"],
    env: ["API_KEY": "foo"])),
].reduce(into: [:]) { acc, value in
  acc[value.name] = value
}

#Preview {
  MCPSettingsView(mcpServers: .constant(sampleMCPServers))
    .frame(width: 600, height: 400)
    .padding()
}

#endif
