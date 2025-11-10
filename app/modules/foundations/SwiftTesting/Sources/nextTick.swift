/// Yields execution to the next run loop tick by scheduling continuation on the main actor.
///
/// This function suspends the current task and resumes it on the main actor's run loop,
/// allowing pending UI updates and other main actor work to complete before continuing.
/// Useful in tests when you need to wait for asynchronous UI state changes or event processing.
public func nextTick() async {
  _ = await withCheckedContinuation { continuation in
    Task {
      await MainActor.run {
        continuation.resume(returning: ())
      }
    }
  }
}
