// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Copied from https://github.com/gsabran/mcp-swift-sdk/blob/main/MCPInterface/Sources/mcp_interfaces/JSON.swift

import Foundation

// MARK: - JSON

public enum JSON: Codable, Equatable, Hashable, Sendable {
  case object(_ value: [String: JSON.Value])
  case array(_ value: [JSON.Value])

  // MARK: - JSONValue

  public enum Value: Codable, Equatable, Hashable, Sendable {
    case string(_ value: String)
    case object(_ value: [String: JSON.Value])
    case array(_ value: [JSON.Value])
    case bool(_ value: Bool)
    case number(_ value: Double)
    case null
  }
}

// MARK: ExpressibleByDictionaryLiteral

extension JSON: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSON.Value)...) {
    self.init(dictionaryLiteral: elements)
  }

  public init(dictionaryLiteral elements: [(String, JSON.Value)]) {
    var object = [String: JSON.Value]()

    for element in elements {
      object[element.0] = element.1
    }

    self = .object(object)
  }

  public init(_ dictionary: [String: some JSONValueConvertible]) {
    self.init(dictionaryLiteral: dictionary.map { k, v in (k, v.asJSONValue) })
  }
}

// MARK: ExpressibleByArrayLiteral

extension JSON: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSON.Value...) {
    var array = [JSON.Value]()

    for element in elements {
      array.append(element)
    }

    self = .array(array)
  }
}

// MARK: - JSON.Value + ExpressibleByNilLiteral

extension JSON.Value: ExpressibleByNilLiteral {
  public init(nilLiteral _: ()) {
    self = .null
  }
}

// MARK: - JSON.Value + ExpressibleByDictionaryLiteral

extension JSON.Value: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSON.Value)...) {
    var object = [String: JSON.Value]()

    for element in elements {
      object[element.0] = element.1
    }

    self = .object(object)
  }
}

// MARK: - JSON.Value + ExpressibleByStringLiteral

extension JSON.Value: ExpressibleByStringLiteral {
  public init(stringLiteral: String) {
    self = .string(stringLiteral)
  }
}

// MARK: - JSON.Value + ExpressibleByIntegerLiteral

extension JSON.Value: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    self = .number(Double(value))
  }
}

// MARK: - JSON.Value + ExpressibleByFloatLiteral

extension JSON.Value: ExpressibleByFloatLiteral {
  public init(floatLiteral value: FloatLiteralType) {
    self = .number(value)
  }
}

// MARK: - JSON.Value + ExpressibleByArrayLiteral

extension JSON.Value: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSON.Value...) {
    var array = [JSON.Value]()

    for element in elements {
      array.append(element)
    }

    self = .array(array)
  }
}

// MARK: - JSON.Value + ExpressibleByBooleanLiteral

extension JSON.Value: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) {
    self = .bool(value)
  }
}

extension JSON {

  public init(from decoder: Decoder) throws {
    do {
      // Object
      let container = try decoder.container(keyedBy: String.self)
      let keys = container.allKeys
      let object = keys.reduce(into: [String: JSON.Value]()) { result, key in
        if let value = try? container.decode(JSON.Value.self, forKey: key) {
          result[key] = value
        }
      }
      self = .object(object)
    } catch {
      // Array
      var container = try decoder.unkeyedContainer()
      var array: [JSON.Value] = []
      while !container.isAtEnd {
        if let value = try? container.decode(JSON.Value.self) {
          array.append(value)
        }
      }
      self = .array(array)
    }
  }

  public static func ==(lhs: JSON, rhs: JSON) -> Bool {
    lhs.asValue == rhs.asValue
  }

  public func encode(to encoder: any Encoder) throws {
    try asValue.encode(to: encoder)
  }

  var asValue: JSON.Value {
    switch self {
    case .object(let value):
      .object(value)
    case .array(let value):
      .array(value)
    }
  }
}

extension JSON.Value {

  public init(from decoder: Decoder) throws {
    do {
      // Single values
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self = .null
      } else if let value = try? container.decode(String.self) {
        self = .string(value)
      } else if let value = try? container.decode(Bool.self) {
        self = .bool(value)
      } else if let value = try? container.decode(Double.self) {
        self = .number(value)
      } else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON")
      }
    } catch {
      // Object
      do {
        let container = try decoder.container(keyedBy: String.self)
        let keys = container.allKeys
        let object = keys.reduce(into: [String: JSON.Value]()) { result, key in
          if let value = try? container.decode(JSON.Value.self, forKey: key) {
            result[key] = value
          }
        }
        self = .object(object)
      } catch {
        // Array
        var container = try decoder.unkeyedContainer()
        var array: [JSON.Value] = []
        while !container.isAtEnd {
          if let value = try? container.decode(JSON.Value.self) {
            array.append(value)
          }
        }
        self = .array(array)
      }
    }
  }

  public static func ==(lhs: JSON.Value, rhs: JSON.Value) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
      true
    case (.string(let lhs), .string(let rhs)):
      lhs == rhs
    case (.bool(let lhs), .bool(let rhs)):
      lhs == rhs
    case (.number(let lhs), .number(let rhs)):
      lhs == rhs
    case (.object(let lhs), .object(let rhs)):
      lhs == rhs
    case (.array(let lhs), .array(let rhs)):
      lhs == rhs
    default:
      false
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()

    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .number(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)

    case .object(let value):
      var container = encoder.container(keyedBy: String.self)
      for (key, value) in value {
        try container.encode(value, forKey: key)
      }

    case .array(let value):
      var container = encoder.unkeyedContainer()
      for value in value {
        try container.encode(value)
      }
    }
  }
}

extension JSON {
  public var asAny: Any {
    switch self {
    case .object(let value):
      value.keys.reduce(into: [String: Any]()) { result, key in
        result[key] = value[key]?.asAny
      }

    case .array(let value):
      value.map(\.asAny)
    }
  }

  public var asObject: [String: JSON.Value]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  public var asArray: [JSON.Value]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  public func asJSONData(options: JSONSerialization.WritingOptions = []) throws -> Data {
    try JSONSerialization.data(withJSONObject: asAny, options: options)
  }

  public func asJSONString(options: JSONSerialization.WritingOptions = []) throws -> String {
    guard let string = try String(data: asJSONData(options: options), encoding: .utf8) else {
      throw NSError(domain: "JSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to string"])
    }
    return string
  }
}

extension JSON.Value {
  public var asAny: Any {
    switch self {
    case .string(let value):
      value

    case .object(let value):
      value.keys.reduce(into: [String: Any]()) { result, key in
        result[key] = value[key]?.asAny
      }

    case .array(let value):
      value.map(\.asAny)

    case .bool(let value):
      value

    case .number(let value):
      value

    case .null:
      NSNull()
    }
  }

  public var asString: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  public var asObject: [String: JSON.Value]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  public var asArray: [JSON.Value]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  public var asBool: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  public var asNumber: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }
}

// MARK: - String + CodingKey

extension String: @retroactive CodingKey {

  public init?(stringValue: String) {
    self = stringValue
  }

  public init?(intValue: Int) {
    self = "\(intValue)"
  }

  public var stringValue: String { self }
  public var intValue: Int? { Int(self) }
}

public protocol JSONValueConvertible {
  var asJSONValue: JSON.Value { get }
}

extension String: JSONValueConvertible {
  public var asJSONValue: JSON.Value { .string(self) }
}

extension Int: JSONValueConvertible {
  public var asJSONValue: JSON.Value { .number(Double(self)) }
}

extension Bool: JSONValueConvertible {
  public var asJSONValue: JSON.Value { .bool(self) }
}

extension Optional: JSONValueConvertible where Wrapped: JSONValueConvertible {
  public var asJSONValue: JSON.Value {
    switch self {
    case .none:
      .null
    case .some(let value):
      value.asJSONValue
    }
  }
}
