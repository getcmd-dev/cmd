// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

// TODO: look at reusing AXSwift?

// MARK: - State

extension AXUIElement {
  public var identifier: String? {
    (try? copyValue(key: kAXIdentifierAttribute))
  }

  public var value: String? {
    (try? copyValue(key: kAXValueAttribute))
  }

  public var intValue: Int? {
    (try? copyValue(key: kAXValueAttribute))
  }

  public var title: String? {
    (try? copyValue(key: kAXTitleAttribute))
  }

  public var role: String? {
    (try? copyValue(key: kAXRoleAttribute))
  }

  public var doubleValue: Double? {
    (try? copyValue(key: kAXValueAttribute))
  }

  public var document: String? {
    try? copyValue(key: kAXDocumentAttribute)
  }

  /// Label in Accessibility Inspector.
  public var description: String? {
    (try? copyValue(key: kAXDescriptionAttribute))
  }

  /// Type in Accessibility Inspector.
  public var roleDescription: String? {
    (try? copyValue(key: kAXRoleDescriptionAttribute))
  }

  public var label: String? {
    (try? copyValue(key: kAXLabelValueAttribute))
  }

  public var isSourceEditor: Bool {
    description == "Source Editor"
  }

  public var selectedTextRange: ClosedRange<Int>? {
    guard let value: AXValue = try? copyValue(key: kAXSelectedTextRangeAttribute)
    else { return nil }
    var range = CFRange(location: 0, length: 0)
    if AXValueGetValue(value, .cfRange, &range) {
      return range.location...(range.location + range.length)
    }
    return nil
  }

  public var isFocused: Bool {
    (try? copyValue(key: kAXFocusedAttribute)) ?? false
  }

  public var isEnabled: Bool {
    (try? copyValue(key: kAXEnabledAttribute)) ?? false
  }

  public var isHidden: Bool {
    (try? copyValue(key: kAXHiddenAttribute)) ?? false
  }

  /// Set global timeout in seconds.
  public static func setGlobalMessagingTimeout(_ timeout: Float) {
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
  }

  /// Set timeout in seconds for this element.
  public func setMessagingTimeout(_ timeout: Float) {
    AXUIElementSetMessagingTimeout(self, timeout)
  }

}

// MARK: - Rect

extension AXUIElement {
  public var position: CGPoint? {
    guard let value: AXValue = try? copyValue(key: kAXPositionAttribute)
    else { return nil }
    var point = CGPoint.zero
    if AXValueGetValue(value, .cgPoint, &point) {
      return point
    }
    return nil
  }

  public var size: CGSize? {
    guard let value: AXValue = try? copyValue(key: kAXSizeAttribute)
    else { return nil }
    var size = CGSize.zero
    if AXValueGetValue(value, .cgSize, &size) {
      return size
    }
    return nil
  }

  public var rect: CGRect? {
    guard let position, let size else { return nil }
    return .init(origin: position, size: size)
  }

  public var appKitFrame: CGRect? {
    cgFrame?.invertedFrame
  }

  public var cgFrame: CGRect? {
    guard let size, let position else { return nil }
    return CGRect(origin: position, size: size)
  }

  /// Set the frame of the element (only works for window) to the desired location in AppKit coordinates (bottom is y=0).
  public func set(appKitframe: CGRect) {
    guard let cgFrame = appKitframe.invertedFrame else {
      return
    }
    var origin = cgFrame.origin
    var size = cgFrame.size
    guard
      let originValue = AXValueCreate(AXValueType.cgPoint, &origin),
      let sizeValue = AXValueCreate(AXValueType.cgSize, &size)
    else {
      return
    }
    AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, originValue)
    AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, sizeValue)
  }
}

// MARK: - Relationship

extension AXUIElement {
  public var focusedElement: AXUIElement? {
    try? copyValue(key: kAXFocusedUIElementAttribute)
  }

  public var sharedFocusElements: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public var window: AXUIElement? {
    try? copyValue(key: kAXWindowAttribute)
  }

  public var windows: [AXUIElement] {
    (try? copyValue(key: kAXWindowsAttribute)) ?? []
  }

  public var isFullScreen: Bool {
    (try? copyValue(key: "AXFullScreen")) ?? false
  }

  public var focusedWindow: AXUIElement? {
    try? copyValue(key: kAXFocusedWindowAttribute)
  }

  public var topLevelElement: AXUIElement? {
    try? copyValue(key: kAXTopLevelUIElementAttribute)
  }

  public var rows: [AXUIElement] {
    (try? copyValue(key: kAXRowsAttribute)) ?? []
  }

  public var parent: AXUIElement? {
    try? copyValue(key: kAXParentAttribute)
  }

  public var children: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public var menuBar: AXUIElement? {
    try? copyValue(key: kAXMenuBarAttribute)
  }

  public var visibleChildren: [AXUIElement] {
    (try? copyValue(key: kAXVisibleChildrenAttribute)) ?? []
  }

  public var verticalScrollBar: AXUIElement? {
    try? copyValue(key: kAXVerticalScrollBarAttribute)
  }

}

// MARK: - AXUIElement + Tree

extension AXUIElement: Tree {
  public typealias Child = AXUIElement
}

public typealias SearchNextStep = TreeSearchNextStep

// MARK: - Helper

extension AXUIElement {
  public var isValid: Bool {
    do {
      let desc: String = try copyValue(key: kAXDescriptionAttribute)
      _ = desc
      return true
    } catch AXError.invalidUIElement, AXError.noValue {
      return false
    } catch AXError.attributeUnsupported {
      return true
    } catch {
      print("Unexpected AX error: \(error)")
      return false
    }
  }

  public func copyValue<T>(key: String, ofType _: T.Type = T.self) throws -> T {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(self, key as CFString, &value)
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }

  public func copyParameterizedValue<T>(
    key: String,
    parameters: AnyObject,
    ofType _: T.Type = T.self)
    throws -> T
  {
    var value: AnyObject?
    let error = AXUIElementCopyParameterizedAttributeValue(
      self,
      key as CFString,
      parameters as CFTypeRef,
      &value)
    if error == .success, let value = value as? T {
      return value
    }
    throw error
  }

}

// MARK: - AXError + @retroactive Error

extension AXError: @retroactive Error { }

extension CGRect {
  /// convert between AppKit coordinate (bottom is y=0) and CG coordinate (top is y=0).
  public var invertedFrame: CGRect? {
    guard
      let screenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
    else { return nil }
    return CGRect(x: minX, y: screenHeight - maxY, width: width, height: height)
  }
}

extension AXUIElement {

  /// A debug description of the element and its children.
  /// It will nicely print out in the console (CFString will break out news lines)
  public var debugDescription: CFString {
    var result = ""
    _buildDebugDescription(element: self, indent: "", isLast: true, into: &result)
    return result as CFString
  }

  private func _buildDebugDescription(element: AXUIElement, indent: String, isLast: Bool, into result: inout String) {
    let prefix = isLast ? "╰─" : "├─"
    let childIndent = indent + (isLast ? "  " : "│ ")

    // Start building the single line description
    result += "\(indent)\(prefix)"

    // Element type/identifier
    if let role = element.role {
      result += "\(role) - "
    } else {
      result += "AXUIElement - "
    }

    if let identifier = element.identifier {
      result += "id: \(identifier)"
    } else if let title = element.title {
      result += "title: \(title)"
    }

    // Append all properties on the same line
    let properties = [
      element.description.map { "description: \($0)" },
      element.roleDescription.map { "roleDescription: \($0)" },
      element.value.map { $0.count > 100 ? "value: \($0.prefix(100))[...]" : "value: \($0)" }?
        .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: ""),
      element.isEnabled ? "enabled: true" : "enabled: false",
      element.isFocused ? "focused: true" : nil,
    ].compactMap(\.self)

    if !properties.isEmpty {
      result += " / " + properties.joined(separator: " / ")
    }

    result += "\n"

    // Children
    let children = element.children
    for (index, child) in children.enumerated() {
      let isLastChild = index == children.count - 1
      _buildDebugDescription(element: child, indent: childIndent, isLast: isLastChild, into: &result)
    }
  }
}
