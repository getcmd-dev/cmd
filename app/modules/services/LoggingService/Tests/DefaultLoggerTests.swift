// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FoundationInterfaces
import Testing
@testable import LoggingService

struct DefaultLoggerTests {
  @Test("deviceId")
  func test_savesDeviceIdToUserDefaults() {
    // Given
    let userDefaults = MockUserDefaults()
    // When
    let sut = DefaultLogger(subsystem: "test", category: "com.app", fileManager: MockFileManager(), userDefaults: userDefaults)
    // Then
    #expect(userDefaults.string(forKey: "deviceId") != nil)
    #expect(sut.deviceId == userDefaults.string(forKey: "deviceId"))
  }

  @Test("deviceId")
  func test_reusesExistingDeviceId() {
    // Given
    let userDefaults = MockUserDefaults(initialValues: ["deviceId": "existing-device-id"])
    // When
    let sut = DefaultLogger(subsystem: "test", category: "com.app", fileManager: MockFileManager(), userDefaults: userDefaults)
    // Then
    #expect(userDefaults.string(forKey: "deviceId") == "existing-device-id")
    #expect(sut.deviceId == "existing-device-id")
  }
}
