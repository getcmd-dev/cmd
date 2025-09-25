// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import DLS
import MCPServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - MCPSettingsView

struct MCPSettingsView: View {
  init(mcpServers: Binding<[String: MCPServerConfiguration]>) {
    _mcpServers = mcpServers
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isCreatingNewServer {
        NewMCPServerCard(
          cancel: {
            isCreatingNewServer = false
          },
          add: { server in
            print("adding \(server)")
          })
      } else {
        HoveredButton(
          action: {
            isCreatingNewServer = true
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 8,
          cornerRadius: 6)
        {
          Text("Add MCP Server")
        }
        .padding(.bottom, 16)

        ScrollView {
          LazyVStack(spacing: 16) {
            ForEach(sampleMCPServers, id: \.name) { server in
              MCPServerCard(
                server: server,
                onToggle: { isEnabled in
                  var server = server
                  server.disabled = !isEnabled
                  mcpServers[server.name] = server
                })
            }
          }
          .padding(.bottom, 20)
        }
      }
    }
  }

  @Binding private var mcpServers: [String: MCPServerConfiguration]
  @Environment(\.colorScheme) private var colorScheme
  @State private var isCreatingNewServer = false

}

// MARK: - Sample Data

private let sampleMCPServers: [MCPServerConfiguration] = [
  MCPServerConfiguration.http(.init(
    name: "Github",
    url: "https://github.com")),
  MCPServerConfiguration.stdio(.init(
    name: "sqlite",
    command: "sqlite",
    args: ["--init", "./sqlite/init.sql"],
    env: ["API_KEY": "foo"])),
]

// MARK: - NewMCPServerCard

private struct NewMCPServerCard: View {
  let cancel: () -> Void
  let add: (MCPServerConfiguration) -> Void
  @State private var raw = """
    {
      "command": "npx",
      "args": ["-y", "mcp-ripgrep@latest"]
    }
    """
  @State private var serverName = "foo"

  var body: some View {
    VStack(alignment: .leading) {
      Text("Server name")
      TextField("", text: $serverName)
      if hasMissingNameError {
        Text("Server name is missing")
          .foregroundColor(colorScheme.redError)
      }

      HStack {
        Text("Server config")

        Spacer(minLength: 0)
        Button(action: {
          isShowingExamples.toggle()
        }, label: {
          Text(isShowingExamples ? "Hide examples" : "Show examples")
            .underline()
            .foregroundColor(.secondary)
        })

        .buttonStyle(PlainButtonStyle())
      }
      RichTextEditor(
        text: .init(
          get: { .init(string: raw) },
          set: { raw = $0.string }),
        onKeyDown: { _, _ in
          false
        })
        .padding(4)
        .with(
          cornerRadius: 8,
          backgroundColor: Color(NSColor.controlBackgroundColor),
          borderColor: Color.gray.opacity(0.2),
          borderWidth: 1)
        .scrollContentBackground(.hidden)
        .fixedSize(horizontal: false, vertical: true)
      if let errorMessage {
        Text(errorMessage)
          .foregroundColor(colorScheme.redError)
      }

      if isShowingExamples {
        VStack(alignment: .leading) {
          Text("STDIO config example:")
          Text("""
            {
              "type": "stdio",
              "command": "node",
              "args": ["build/index.js", "--debug"],
              "env": {
                "API_KEY": "your-api-key",
                "DEBUG": "true"
              }
            }
            """)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
          .padding()
          .with(
            cornerRadius: 8,
            backgroundColor: colorScheme.tertiarySystemBackground,
            borderColor: Color.gray.opacity(0.2),
            borderWidth: 1)

          Text("HTTP config example:")
          Text("""
            {
              "type": "http",
              "url": "http://localhost:3000/mcp"
              "headers": {
                "Authorization": "..."
              }
            }
            """)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
          .padding()
          .with(
            cornerRadius: 8,
            backgroundColor: colorScheme.tertiarySystemBackground,
            borderColor: Color.gray.opacity(0.2),
            borderWidth: 1)
        }
        .padding(.vertical, 8)
      }

      HStack {
        HoveredButton(
          action: {
            Task {
              _ = await testServer()
            }
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 5,
          cornerRadius: 6)
        {
          Text("Test")
        }
        HoveredButton(
          action: {
            Task {
              _ = await addServer()
            }
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 5,
          cornerRadius: 6)
        {
          Text("Add")
        }
        HoveredButton(
          action: {
            cancel()
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 5,
          cornerRadius: 6)
        {
          Text("Cancel")
        }
      }
      Spacer()
    }
  }

  private func addServer() async {
    guard let mcpServer = await testServer() else { return }
    add(mcpServer)
  }

  private func testServer() async -> MCPServerConfiguration? {
    errorMessage = nil
    hasMissingNameError = false

    let name = serverName
    if name.isEmpty {
      hasMissingNameError = true
      return nil
    }
    do {
      guard
        let data = "{ \"\(name)\": \(raw) }".data(using: .utf8),
        let mcpServer = try JSONDecoder().decode(MCPServerConfigurations.self, from: data).configurations[name]
      else {
        throw AppError("Could not parse content")
      }

      _ = try await mcpService.connect(to: mcpServer)
      return mcpServer
    } catch {
      errorMessage = error.debugDescription
      return nil
    }
  }

  @Dependency(\.mcpService) private var mcpService

  @State private var errorMessage: String?
  @State private var hasMissingNameError = false
  @State private var isShowingExamples = false
  @Environment(\.colorScheme) private var colorScheme
  @State private var name = ""
  @State private var url = ""
  @State private var command = ""

  @State private var args = [""] {
    didSet {
      guard oldValue != args else { return }
      args = args.filter { !$0.isEmpty } + [""]
    }
  }

  @State private var env: [EnvVariable] = [EnvVariable(key: "", value: "")] {
    didSet {
      guard oldValue != env else { return }
      env = env.filter { !$0.key.isEmpty || !$0.value.isEmpty } + [EnvVariable(key: "", value: "")]
    }
  }

}

// MARK: - MCPServerCard

private struct MCPServerCard: View {
  let server: MCPServerConfiguration
  let onToggle: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 0) {
        Text(server.name)
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()

        // Toggle switch
        if isHovered {
          HoveredButton(
            action: {
//                      editingShortcut = shortcut
            },
            onHoverColor: colorScheme.secondarySystemBackground,
            padding: 6,
            cornerRadius: 6)
          {
            Image(systemName: "pencil")
              .font(.system(size: 12, weight: .medium))
          }
          .padding(.trailing, 6)
        }
        Toggle("", isOn: Binding(
          get: { !server.disabled },
          set: { newValue in
            onToggle(newValue)
          }))
          .toggleStyle(SwitchToggleStyle())
      }
      .frame(minHeight: 30)

      switch server {
      case .http(let configuration):
        HStack {
          Text(configuration.url)
        }

      case .stdio(let configuration):
        HStack {
          Text("\(configuration.command) \((configuration.args ?? []).joined(separator: " "))")
        }
        if let env = configuration.env, !env.isEmpty {
          VStack(alignment: .leading) {
            ForEach(Array(env.keys.enumerated()), id: \.0) { _, key in
              HStack {
                Text("\(key):")
                  .fontWeight(.light)
                  .foregroundColor(.secondary)
                Text(env[key] ?? "")
              }
            }
          }
        }
      }
    }

    .padding(16)
    .onHover { isHovered in
      self.isHovered = isHovered
    }
    .with(
      cornerRadius: 8,
      backgroundColor: Color(NSColor.controlBackgroundColor),
      borderColor: Color.gray.opacity(0.2),
      borderWidth: 1)
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var isHovered = false
}

extension MCPServerConfiguration {
  var transportDescription: String {
    switch self {
    case .http:
      "HTTP"
    case .stdio:
      "STDIO"
    }
  }
}

// MARK: - MCPTransport

private enum MCPTransport {
  case stdio
  case http
}

// MARK: - EnvVariable

struct EnvVariable: Equatable {
  let key: String
  let value: String
}
