// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation

// MARK: - GitHubCopilotConfiguration

struct GitHubCopilotConfiguration: Codable {
  var enable: [String: Bool]? // e.g. {"*": true}
  var advanced: [String: JSON.Value]?

  static var `default`: GitHubCopilotConfiguration {
    GitHubCopilotConfiguration(
      enable: ["*": true],
      advanced: [:])
  }
}

// MARK: - GitHubEnterpriseConfiguration

struct GitHubEnterpriseConfiguration: Codable {
  var uri: String?

  static var `default`: GitHubEnterpriseConfiguration {
    GitHubEnterpriseConfiguration(uri: nil)
  }
}

// MARK: - HTTPConfiguration

struct HTTPConfiguration: Codable {
  var proxy: String?
  var proxyStrictSSL: Bool?

  static var `default`: HTTPConfiguration {
    HTTPConfiguration(
      proxy: "",
      proxyStrictSSL: true)
  }
}

// MARK: - TelemetryConfiguration

struct TelemetryConfiguration: Codable {
  var enable: Bool?

  static var `default`: TelemetryConfiguration {
    TelemetryConfiguration(enable: false)
  }
}

// MARK: - WorkspaceConfigurationBuilder

/// Helper to build configuration responses for workspace/configuration requests
enum WorkspaceConfigurationBuilder {
  static func buildResponse(
    for request: WorkspaceConfigurationRequestParameters,
    copilotConfiguration: GitHubCopilotConfiguration = .default,
    enterpriseConfiguration: GitHubEnterpriseConfiguration = .default,
    httpConfiguration: HTTPConfiguration = .default,
    telemetryConfiguration: TelemetryConfiguration = .default)
    throws -> JSON.Value
  {
    try .array(request.items.map { item in
      switch item.section {
      case "github.copilot":
        try .init(encoding: copilotConfiguration)
      case "github-enterprise":
        try .init(encoding: enterpriseConfiguration)
      case "http":
        try .init(encoding: httpConfiguration)
      case "telemetry":
        try .init(encoding: telemetryConfiguration)
      default:
        JSON.Value.object([:])
      }
    })
  }
}
