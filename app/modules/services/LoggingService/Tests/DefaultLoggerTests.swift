// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import FoundationInterfaces
import Testing
@testable import LoggingService

struct DefaultLoggerTests {
  @Test("deviceId")
  func savesDeviceIdToUserDefaults() {
    // Given
    let userDefaults = MockUserDefaults()
    // When
    let sut = DefaultLogger(subsystem: "test", category: "com.app", fileManager: MockFileManager(), userDefaults: userDefaults)
    // Then
    #expect(userDefaults.string(forKey: "deviceId") != nil)
    #expect(sut.deviceId == userDefaults.string(forKey: "deviceId"))
  }

  @Test("deviceId")
  func reusesExistingDeviceId() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["deviceId": "existing-device-id"])
    // When
    let sut = DefaultLogger(subsystem: "test", category: "com.app", fileManager: MockFileManager(), userDefaults: userDefaults)
    // Then
    #expect(userDefaults.string(forKey: "deviceId") == "existing-device-id")
    #expect(sut.deviceId == "existing-device-id")
  }

  @Test("log level filtering - writes messages at or above configured level")
  func writesMessagesAtOrAboveConfiguredLevel() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["defaultLogLevel": "warn"])
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")
    sut.notice("notice message")
    sut.error("error message")

    // Then - only notice (warn) and error should be written
    #expect(writtenMessages.value.count == 2)
    #expect(writtenMessages.value[0].contains("[Notice] notice message"))
    #expect(writtenMessages.value[1].contains("[Error] error message"))
  }

  @Test("log level filtering - default level is info when not configured")
  func defaultLevelIsInfoWhenNotConfigured() {
    // Given
    let userDefaults = MockUserDefaults()
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")
    sut.log("log message")

    // Then - trace and debug should be filtered out, info and log should be written
    #expect(writtenMessages.value.count == 2)
    #expect(writtenMessages.value[0].contains("[Info] info message"))
    #expect(writtenMessages.value[1].contains("[Log] log message"))
  }

  @Test("log level filtering - trace level writes all messages")
  func traceLevelWritesAllMessages() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["defaultLogLevel": "trace"])
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")
    sut.notice("notice message")
    sut.error("error message")

    // Then - all messages should be written
    #expect(writtenMessages.value.count == 5)
    #expect(writtenMessages.value[0].contains("[Trace] trace message"))
    #expect(writtenMessages.value[1].contains("[Debug] debug message"))
    #expect(writtenMessages.value[2].contains("[Info] info message"))
    #expect(writtenMessages.value[3].contains("[Notice] notice message"))
    #expect(writtenMessages.value[4].contains("[Error] error message"))
  }

  @Test("log level filtering - critical level only writes critical and above")
  func criticalLevelOnlyWritesCriticalAndAbove() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["defaultLogLevel": "critical"])
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")
    sut.notice("notice message")
    sut.error("error message")

    // Then - no messages should be written since there's no critical() method
    #expect(writtenMessages.value.count == 0)
  }

  @Test("log level filtering - error level writes only errors")
  func errorLevelWritesOnlyErrors() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["defaultLogLevel": "error"])
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")
    sut.notice("notice message")
    sut.error("error message")

    // Then - only error should be written
    #expect(writtenMessages.value.count == 1)
    #expect(writtenMessages.value[0].contains("[Error] error message"))
  }

  @Test("log level filtering - invalid log level falls back to info")
  func invalidLogLevelFallsBackToInfo() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["defaultLogLevel": "invalid"])
    let writtenMessages = Atomic<[String]>([])
    let sut = DefaultLogger(
      subsystem: "test",
      category: "com.app",
      fileManager: MockFileManager(),
      userDefaults: userDefaults,
      writeToFile: { message in
        writtenMessages.mutate { $0.append(message) }
      })

    // When
    sut.trace("trace message")
    sut.debug("debug message")
    sut.info("info message")

    // Then - should default to info level
    #expect(writtenMessages.value.count == 1)
    #expect(writtenMessages.value[0].contains("[Info] info message"))
  }
}
