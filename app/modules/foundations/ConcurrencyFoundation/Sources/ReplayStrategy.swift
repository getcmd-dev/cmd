// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/// Describe which past events should be sent to an iterator when it is created from an async sequence.
public enum ReplayStrategy: Sendable {
  /// Do not send any past events when the iterator is created.
  case noReplay
  /// Send only the last event, if any, to the iterator when it is created.
  case replayLast
  /// Send all past events to the iterator when it is created.
  case replayAll
}
