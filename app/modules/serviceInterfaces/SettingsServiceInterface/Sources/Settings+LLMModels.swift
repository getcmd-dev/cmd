// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import LLMFoundation

extension SettingsServiceInterface.Settings {

  /// A model that can be used for simple queries that favor speed & low cost over accuracy.
  public var lowTierModel: LLMModel? { // TODO
    nil
//    let preferredLowTierModels: [LLMModel] = [
//      .claudeHaiku_3_5,
//      .gpt_mini,
//      .gpt_oss_20b,
//    ]
//    return availableModels.sorted(by: { a, b in
//      let i = preferredLowTierModels.firstIndex(of: a)
//      let j = preferredLowTierModels.firstIndex(of: b)
//
//      switch (i, j) {
//      case (let i?, let j?): return i < j
//      case (_?, nil): return true
//      case (nil, _?): return false
//      case (nil, nil): return (a.defaultPricing?.input ?? .greatestFiniteMagnitude) <
//        (b.defaultPricing?.input ?? .greatestFiniteMagnitude)
//      }
//    }).first
  }
}
