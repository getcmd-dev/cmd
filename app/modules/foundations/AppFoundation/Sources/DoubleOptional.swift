/// Custom operator for unwrapping double optionals (Optional<Optional<T>>)
/// This operator provides a convenient way to handle nested optionals with a default value
infix operator ???

/// Unwraps a double optional value, returning the inner value if present, or the default value otherwise
/// - Parameters:
///   - value: A double optional value (Optional<Optional<T>>)
///   - default: The default value to return if either optional layer is nil
/// - Returns: The unwrapped value if both optional layers contain a value, otherwise the default
/// - Example:
///   ```swift
///   let doubleOptional: Int?? = 42
///   let result = doubleOptional ??? 0  // Returns 42
///
///   let nilOuter: Int?? = nil
///   let result2 = nilOuter ??? 0  // Returns 0
///
///   let nilInner: Int?? = Optional<Int>.none
///   let result3 = nilInner ??? 0  // Returns 0
///   ```
public func ??? <T>(value: T??, default: T) -> T {
  switch value {
  case .some(let wrapped):
    // If outer optional has value, unwrap inner optional with ?? operator
    wrapped ?? `default`
  case .none:
    // If outer optional is nil, return default
    `default`
  }
}
