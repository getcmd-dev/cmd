// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SettingsServiceInterface

extension Settings.ChatModeConfiguration: Codable {

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    try self.init(
      customInstructions: container.decodeIfPresent(String.self, forKey: .customInstructions),
      availableToolIds: container.decodeIfPresent([String].self, forKey: .availableToolIds))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(customInstructions, forKey: .customInstructions)
    if let availableToolIds {
      // Ensure that we don't have duplicated values before encoding
      try container.encode(Array(Set(availableToolIds)).sorted(), forKey: .availableToolIds)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case customInstructions
    case availableToolIds = "tools"
  }
}
