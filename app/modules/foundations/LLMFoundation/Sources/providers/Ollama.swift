// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {
  public static let ollama = AIProvider(
    id: "ollama",
    name: "Ollama",
    websiteURL: URL(string: "https://ollama.com/search"))
}
