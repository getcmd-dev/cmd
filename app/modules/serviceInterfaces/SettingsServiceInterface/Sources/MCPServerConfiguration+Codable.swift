// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - MCPServerConfiguration Codable Support

extension MCPServerConfiguration {
  public init(from decoder: Decoder, name: String) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let type: ServerType = try {
      if !container.contains(.type) {
        return .stdio
      }
      return try container.decode(ServerType.self, forKey: .type)
    }()

    switch type {
    case .stdio:
      let config = try MCPServerStdioConfiguration(from: decoder, name: name)
      self = .stdio(config)

    case .http:
      let config = try MCPServerHttpConfiguration(from: decoder, name: name)
      self = .http(config)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .stdio(let config):
      try container.encode(ServerType.stdio, forKey: .type)
      try config.encode(to: encoder)

    case .http(let config):
      try container.encode(ServerType.http, forKey: .type)
      try config.encode(to: encoder)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }

  private enum ServerType: String, Codable {
    case stdio
    case http
  }

}

// MARK: - MCPServerStdioConfiguration Codable Support

extension MCPServerConfiguration.MCPServerStdioConfiguration {
  public init(from decoder: any Decoder, name: String) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let command = try container.decode(String.self, forKey: .command)
    let args = try container.decodeIfPresent([String].self, forKey: .args)
    let env = try container.decodeIfPresent([String: String].self, forKey: .env)
    let disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    let disabledToolNames = try container.decodeIfPresent([String].self, forKey: .disabledToolNames)

    self.init(
      name: name,
      command: command,
      args: args,
      env: env,
      disabled: disabled,
      disabledToolNames: disabledToolNames)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(command, forKey: .command)
    try container.encodeIfPresent(args, forKey: .args)
    if env?.isEmpty == false {
      try container.encodeIfPresent(env, forKey: .env)
    }
    if disabled {
      try container.encode(disabled, forKey: .disabled)
    }
    if disabledToolNames?.isEmpty == false {
      try container.encodeIfPresent(disabledToolNames, forKey: .disabledToolNames)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case command
    case args
    case env
    case disabled
    case disabledToolNames
  }
}

// MARK: - MCPServerHttpConfiguration Codable Support

extension MCPServerConfiguration.MCPServerHttpConfiguration {
  public init(from decoder: any Decoder, name: String) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let url = try container.decode(String.self, forKey: .url)
    let headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
    let disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    let disabledToolNames = try container.decodeIfPresent([String].self, forKey: .disabledToolNames)

    self.init(
      name: name,
      url: url,
      headers: headers,
      disabled: disabled,
      disabledToolNames: disabledToolNames)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(url, forKey: .url)
    if headers?.isEmpty == false {
      try container.encodeIfPresent(headers, forKey: .headers)
    }
    if disabled {
      try container.encode(disabled, forKey: .disabled)
    }
    if disabledToolNames?.isEmpty == false {
      try container.encodeIfPresent(disabledToolNames, forKey: .disabledToolNames)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case url
    case headers
    case disabled
    case disabledToolNames
  }
}

// MARK: - MCPServerConfigurations

public struct MCPServerConfigurations: Codable, Sendable, Equatable {
  public init(from decoder: Decoder) throws {
    var result = [String: MCPServerConfiguration]()

    let container = try decoder.container(keyedBy: String.self)
    let serverNames = container.allKeys
    for serverName in serverNames {
      let nestedDecoder = try container.superDecoder(forKey: serverName)
      result[serverName] = try MCPServerConfiguration(from: nestedDecoder, name: serverName)
    }
    configurations = result
  }

  public init(configurations: [String: MCPServerConfiguration]) {
    self.configurations = configurations
  }

  public var configurations: [String: MCPServerConfiguration]

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    for (key, value) in configurations {
      try value.encode(to: container.superEncoder(forKey: key))
    }
  }
}
