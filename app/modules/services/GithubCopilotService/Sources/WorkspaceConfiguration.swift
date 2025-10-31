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
  static func buildResponse(for items: [[String: Any]]) throws -> [[String: Any]] {
    items.map { item in
      guard let section = item["section"] as? String else {
        return [:]
      }

      switch section {
      case "github.copilot":
        return try! encodeToDictionary(GitHubCopilotConfiguration.default)
      case "github-enterprise":
        return try! encodeToDictionary(GitHubEnterpriseConfiguration.default)
      case "http":
        return try! encodeToDictionary(HTTPConfiguration.default)
      case "telemetry":
        return try! encodeToDictionary(TelemetryConfiguration.default)
      default:
        return [:]
      }
    }
  }

  private static func encodeToDictionary(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return dict ?? [:]
  }
}
