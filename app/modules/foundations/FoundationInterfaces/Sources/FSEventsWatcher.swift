// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import Foundation

import CoreServices

// MARK: - FSEventsWatcher

/// A wrapper around FSEvents API for monitoring file system changes
/// This implementation follows the pattern from CopilotForXcode's FSEventsWrapper
public final class FSEventsWatcher: @unchecked Sendable {

  /// Initialize a new FSEvents watcher
  ///
  /// - Parameters:
  ///   - paths: Array of paths to watch
  ///   - flags: FSEvent stream creation flags
  ///   - queue: Dispatch queue on which to execute the callback (defaults to global queue)
  ///   - eventHandler: Callback to invoke when file system events occur
  public init(
    paths: [String],
    flags: FSEventStreamCreateFlags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents),
    queue: DispatchQueue = .global(),
    eventHandler: @escaping EventHandler)
  {
    self.eventHandler = eventHandler
    self.queue = queue

    var context = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(self as AnyObject).toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil)

    let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
      guard let info = clientCallBackInfo else { return }
      let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()

      // eventPaths is a CFArray when using kFSEventStreamCreateFlagUseCFTypes
      guard let paths = unsafeBitCast(eventPaths, to: CFArray.self) as? [String] else {
        return
      }

      var events = [FileSystemEvent]()

      for i in 0..<Int(numEvents) {
        let path = paths[i]
        let flags = eventFlags[i]
        let eventId = eventIds[i]

        if let event = FileSystemEvent(path: path, flags: flags, eventId: eventId) {
          events.append(event)
        }
      }

      if !events.isEmpty {
        watcher.eventHandler(events)
      }
    }

    // Use kFSEventStreamCreateFlagUseCFTypes to get CFArray instead of C array
    let actualFlags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | Int(flags))

    eventStream = FSEventStreamCreate(
      kCFAllocatorDefault,
      callback,
      &context,
      paths as CFArray,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      1, // latency in seconds
      actualFlags)
  }

  deinit {
    stop()
    if let stream = eventStream {
      FSEventStreamRelease(stream)
    }
  }

  /// Callback type for file system events
  public typealias EventHandler = @Sendable ([FileSystemEvent]) -> Void

  /// Start watching for file system events
  public func start() {
    guard let stream = eventStream else { return }
    FSEventStreamSetDispatchQueue(stream, queue)
    FSEventStreamStart(stream)
  }

  /// Stop watching for file system events
  public func stop() {
    guard let stream = eventStream else { return }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
  }

  private var eventStream: FSEventStreamRef?
  private let eventHandler: EventHandler
  private let queue: DispatchQueue

}

// MARK: - FileSystemEvent

/// Represents a file system event from FSEvents
public struct FileSystemEvent: Sendable {
  public init?(path: String, flags: FSEventStreamEventFlags, eventId: FSEventStreamEventId) {
    // Filter out events we don't care about
    guard flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) == 0 else {
      return nil
    }

    self.path = path
    self.flags = flags
    self.eventId = eventId
  }

  public let path: String
  public let eventId: FSEventStreamEventId
  public let flags: FSEventStreamEventFlags

  public var isCreated: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
  }

  public var isRemoved: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0
  }

  public var isModified: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0
  }

  public var isRenamed: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
  }

  public var isInodeMetadataModified: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod) != 0
  }

  public var isFile: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0
  }

  public var isDirectory: Bool {
    flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir) != 0
  }

}
