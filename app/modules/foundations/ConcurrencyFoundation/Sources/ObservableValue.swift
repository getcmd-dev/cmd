// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// swiftformat:disable unusedPrivateDeclarations
import Combine
import Foundation
import Observation
import SwiftUI

// MARK: - ObservableValue

/// An observable object that wraps a value and publishes changes to it.
@dynamicMemberLookup
@Observable
@MainActor
public class ObservableValue<Value: Sendable>: @unchecked Sendable, Identifiable {

  /// Initialize with a publisher that emits updates.
  public convenience init(_ value: AnyPublisher<Value, Never>, initial: Value) {
    self.init(initial)

    value.sink { [weak self] value in
      Task { @MainActor [weak self] in
        self?.value = value
      }
    }.store(in: &cancellables)
  }

  /// Initialize with a stream that emits updates, and signal when the updates are done.
  public convenience init(initial: Value, updates: AsyncStream<Value>) {
    self.init(initial)

    Task { [weak self] in
      for await value in updates {
        Task { @MainActor [weak self] in
          self?.value = value
        }
      }
    }
  }

  public convenience init(initial: Value, update: @escaping () async -> Value) {
    self.init(initial)

    Task { [weak self] in
      let value = await update()
      Task { @MainActor [weak self] in
        self?.value = value
      }
    }
  }

  public init(_ initial: Value) {
    value = initial
  }

  public let id = UUID()

  @MainActor public var value: Value

  public static func constant(_ value: Value) -> ObservableValue<Value> {
    ObservableValue(Just(value).eraseToAnyPublisher(), initial: value)
  }

  public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
    value[keyPath: keyPath]
  }

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

}

extension ObservableValue {
  public var binding: Binding<Value> {
    Binding(
      get: { self.value },
      set: { self.value = $0 })
  }
}
