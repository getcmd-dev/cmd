// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import DLS
import MCPServiceInterface
import SettingsServiceInterface
import SwiftUI
import ToolFoundation

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
          save: { serverConfiguration in
            mcpServers[serverConfiguration.name] = serverConfiguration
            isCreatingNewServer = false
          },
          saveLabel: "Add")
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
            ForEach(Array(mcpServers.values), id: \.name) { server in
              MCPServerCard(
                server: server,
                onToggle: { isEnabled in
                  var server = server
                  server.disabled = !isEnabled
                  mcpServers[server.name] = server
                },
                onDelete: {
                  mcpServers.removeValue(forKey: server.name)
                },
                onEdit: { serverConfiguration in
                  mcpServers[serverConfiguration.name] = serverConfiguration
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

// MARK: - NewMCPServerCard

private struct NewMCPServerCard: View {
  let cancel: () -> Void
  let save: (MCPServerConfiguration) -> Void
  let saveLabel: String
  @State private var raw = """
    {
      "command": "npx",
      "args": ["-y", "mcp-ripgrep@latest"]
    }
    """

  var body: some View {
    VStack(alignment: .leading) {
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
          Text("Note: you can refer to env variables available in the interactive shell when specifying the headers or args.")
            .font(.callout)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
      }

      if isConnecting {
        ThreeDotsLoadingAnimation(baseText: "Connecting")
      } else if isValidating {
        ThreeDotsLoadingAnimation(baseText: "Validating")
      } else {
        HStack {
          HoveredButton(
            action: {
              Task {
                do {
                  errorMessage = nil
                  isConnecting = true
                  mcpServerConnection = nil
                  mcpServerConnection = try await connectToServer()
                  isConnecting = false
                } catch {
                  isConnecting = false
                  errorMessage = error.localizedDescription
                }
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
                do {
                  isValidating = true
                  errorMessage = nil
                  _ = try await saveServer()
                  isValidating = false
                } catch {
                  errorMessage = error.localizedDescription
                  isValidating = false
                }
              }
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: colorScheme.secondarySystemBackground,
            padding: 5,
            cornerRadius: 6)
          {
            Text(saveLabel)
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
      }
      if let connection = mcpServerConnection {
        VStack(alignment: .leading, spacing: 8) {
          Text("Connection successful!")
            .foregroundColor(colorScheme.greenSuccess)
          Text("\(connection.serverInfo.name) (\(connection.serverInfo.version))")
            .textSelection(.enabled)
          if connection.tools.isEmpty {
            Text("No tool found")
              .foregroundColor(colorScheme.redError)
          } else {
            Text("Tools:")
              .font(.headline)
            ScrollView {
              LazyVStack(alignment: .leading) {
                ForEach(connection.tools, id: \.name) { tool in
                  VStack(alignment: .leading) {
                    Text(originalName(for: tool))
                      .textSelection(.enabled)
                      .font(.headline)
                    Text(tool.description)
                      .textSelection(.enabled)
                      .foregroundColor(.secondary)
                  }
                  .padding(.bottom, 4)
                }
              }
            }
          }
        }
        .padding(.top, 16)
      }
      Spacer()
    }
  }

  /// Extracts the original tool name by removing the "mcp__<serverName>__" prefix.
  private func originalName(for mcpTool: any Tool) -> String {
    mcpTool.name.replacingOccurrences(of: "mcp__", with: "").components(separatedBy: "__").dropFirst().joined(separator: "__")
  }

  private func saveServer() async throws {
    let mcpServerConnection = try await connectToServer()
    // Read the server name from the connection info
    let serverName = mcpServerConnection.serverInfo.name
    guard
      let data = "{ \"\(serverName)\": \(raw) }".data(using: .utf8),
      let mcpServerConfig = try JSONDecoder().decode(MCPServerConfigurations.self, from: data).configurations[serverName]
    else {
      throw AppError("Could not parse content")
    }
    save(mcpServerConfig)
  }

  private func connectToServer() async throws -> MCPServerConnection {
    let tmpConfigurationName = "tmp-mcp-server"
    guard
      let data = "{ \"\(tmpConfigurationName)\": \(raw) }".data(using: .utf8),
      let mcpServerConfig = try JSONDecoder().decode(MCPServerConfigurations.self, from: data)
        .configurations[tmpConfigurationName]
    else {
      throw AppError("Could not parse content")
    }

    return try await mcpService.connect(to: mcpServerConfig)
  }

  @Dependency(\.mcpService) private var mcpService
  @State private var serverName: String? = nil

  @State private var isConnecting = false
  @State private var isValidating = false
  @State private var mcpServerConnection: MCPServerConnection? = nil
  @State private var errorMessage: String?
  @State private var isShowingExamples = false
  @Environment(\.colorScheme) private var colorScheme
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
  let onDelete: () -> Void
  let onEdit: (MCPServerConfiguration) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 0) {
        Text(server.name)
          .textSelection(.enabled)
          .font(.headline)
          .foregroundColor(.primary)
        Spacer()

        if isEditing {
          Text("Editing")
            .foregroundColor(.secondary)
        } else {
          if isHovered {
            HoveredButton(
              action: {
                isEditing = true
              },
              onHoverColor: colorScheme.secondarySystemBackground,
              padding: 6,
              cornerRadius: 6)
            {
              Image(systemName: "pencil")
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.trailing, 6)

            HoveredButton(
              action: {
                onDelete()
              },
              onHoverColor: colorScheme.secondarySystemBackground,
              padding: 6,
              cornerRadius: 6)
            {
              Image(systemName: "trash")
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
      }
      .frame(minHeight: 30)

      switch server {
      case .http(let configuration):
        HStack {
          Text(configuration.url)
            .textSelection(.enabled)
        }

      case .stdio(let configuration):
        HStack {
          Text("\(configuration.command) \((configuration.args ?? []).joined(separator: " "))")
            .textSelection(.enabled)
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

      if isEditing {
        NewMCPServerCard(
          cancel: {
            isEditing = false
          },
          save: { serverConfiguration in
            isEditing = false
            onEdit(serverConfiguration)
          },
          saveLabel: "Save")
          .padding(.top, 16)
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
  @State private var isEditing = false
}

// MARK: - EnvVariable

struct EnvVariable: Equatable {
  let key: String
  let value: String
}
