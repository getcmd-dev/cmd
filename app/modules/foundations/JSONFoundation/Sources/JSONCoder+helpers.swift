// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

extension JSONEncoder {
  public convenience init(outputFormatting: JSONEncoder.OutputFormatting) {
    self.init()
    self.outputFormatting = outputFormatting
  }

  public static var sortingKeys: JSONEncoder {
    JSONEncoder(outputFormatting: [.sortedKeys])
  }
}
