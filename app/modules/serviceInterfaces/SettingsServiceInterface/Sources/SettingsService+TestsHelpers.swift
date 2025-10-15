// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation

#if DEBUG
extension [String: AIProvider] {
  public init(_ values: [AIModel: AIProvider]) {
    self = Dictionary(uniqueKeysWithValues: values.map { ($0.key.id, $0.value) })
  }

  public subscript(info: AIModel) -> AIProvider? {
    get { self[info.id] }
    set { self[info.id] = newValue }
  }
}

extension [String: LLMReasoningSetting] {
  public init(_ values: [AIModel: LLMReasoningSetting]) {
    self = Dictionary(uniqueKeysWithValues: values.map { ($0.key.id, $0.value) })
  }

  public subscript(info: AIModel) -> LLMReasoningSetting? {
    get { self[info.id] }
    set { self[info.id] = newValue }
  }
}
#endif
