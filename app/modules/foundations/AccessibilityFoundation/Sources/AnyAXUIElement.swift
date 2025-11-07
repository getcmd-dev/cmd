// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

// MARK: - AnyAXUIElement

/// A wrapped around `AXUIElement` that allows for mocking, and to remove a dependency on AppKit for higher level code.
public final class AnyAXUIElement: Equatable, Sendable {

  public init(
    isOnScreen _: @escaping @Sendable () -> Bool,
    raise: @Sendable @escaping () -> Void,
    appKitFrame: @Sendable @escaping () -> CGRect?,
    cgFrame: @Sendable @escaping () -> CGRect?,
    pid: @Sendable @escaping () -> pid_t,
    setAppKitframe: @Sendable @escaping (CGRect) -> Void,
    debugDescription _: CFString?,
    id: String)
  {
    _raise = raise
    _appKitFrame = appKitFrame
    _cgFrame = cgFrame
    _pid = pid
    _setAppKitframe = setAppKitframe
    self.id = .string(id)
    wrappedValue = nil
  }

  public init(_ el: AXUIElement) {
    _raise = {
      AXUIElementPerformAction(el, kAXRaiseAction as CFString)
    }
    _appKitFrame = { el.appKitFrame }
    _cgFrame = { el.cgFrame }
    _pid = {
      var pid: pid_t = 0
      let error = AXUIElementGetPid(el, &pid)
      if error != .success {
        return nil
      }
      return pid
    }
    _setAppKitframe = { frame in
      el.set(appKitframe: frame)
    }
    id = .concrete(el)
    wrappedValue = el
  }

  // TODO: try to get rid of this.
  public let wrappedValue: AXUIElement?

  public var appKitFrame: CGRect? {
    _appKitFrame()
  }

  public var cgFrame: CGRect? {
    _cgFrame()
  }

  public var pid: pid_t? {
    _pid()
  }

  public var debugDescription: CFString? {
    wrappedValue?.debugDescription
  }

  public static func ==(lhs: AnyAXUIElement, rhs: AnyAXUIElement) -> Bool {
    lhs.id == rhs.id
  }

  public func raise() {
    _raise()
  }

  public func set(appKitframe: CGRect) {
    _setAppKitframe(appKitframe)
  }

  private enum WrappedIdentifiableObject: Sendable, Equatable {
    case concrete(_ el: AXUIElement)
    case string(_ id: String)
  }

  private let id: WrappedIdentifiableObject
  private let _raise: @Sendable () -> Void
  private let _appKitFrame: @Sendable () -> CGRect?
  private let _cgFrame: @Sendable () -> CGRect?
  private let _pid: @Sendable () -> pid_t?
  private let _setAppKitframe: @Sendable (CGRect) -> Void

}

// MARK: - AXUIElement + @retroactive @unchecked Sendable

extension AXUIElement: @retroactive @unchecked Sendable { }
