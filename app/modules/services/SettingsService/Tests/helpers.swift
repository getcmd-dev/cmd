// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface

extension [String: LLMProvider] {
  init(_ values: [LLMModelInfo: LLMProvider]) {
    self = Dictionary(uniqueKeysWithValues: values.map { ($0.key.id, $0.value) })
  }

  subscript(info: LLMModelInfo) -> LLMProvider? {
    get { self[info.id] }
    set { self[info.id] = newValue }
  }
}

extension [String: LLMReasoningSetting] {
  init(_ values: [LLMModelInfo: LLMReasoningSetting]) {
    self = Dictionary(uniqueKeysWithValues: values.map { ($0.key.id, $0.value) })
  }

  subscript(info: LLMModelInfo) -> LLMReasoningSetting? {
    get { self[info.id] }
    set { self[info.id] = newValue }
  }
}
