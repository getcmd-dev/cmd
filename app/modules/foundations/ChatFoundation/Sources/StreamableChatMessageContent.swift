
/// An object that can be represented in a streamed response.
///
/// Importantly, a stream expects to receive a unique representation of any identifiable object that should not change.
/// If a `StreamRepresentable` has not yet entered its final state, it should not yet represent itself.
public protocol StreamRepresentable: Sendable, Identifiable {
  /// The representation of the object, or `nil` if the object should not yet be streamed.
  @MainActor
  var streamRepresentation: String? { get }
}
