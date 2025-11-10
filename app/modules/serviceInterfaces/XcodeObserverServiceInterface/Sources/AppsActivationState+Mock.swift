// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation

extension AppsActivationState {
  public static func mockPublisher() -> ReadonlyCurrentValueSubject<AppsActivationState> {
    .init(.inactive, publisher: Just(.inactive).eraseToAnyPublisher())
  }
}
