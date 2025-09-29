// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import ShellServiceInterface
import SwiftTesting
import Testing
@testable import PermissionsService

// MARK: - DefaultPermissionsServiceTests

struct DefaultPermissionsServiceTests {

  static let xcodeExtensionNotRunningStdout = """
    me           36684   1.4  0.2 412383248  91008   ??  S     3:11PM   0:00.27 /Applications/cmd.app/Contents/MacOS/cmd
    me           35742   0.0  0.0 410724160   1520 s003  S+    3:08PM   0:00.00 grep --color=auto command
    """

  static let xcodeExtensionRunningStdout = """
    me           36684   1.4  0.2 412383248  91008   ??  S     3:11PM   0:00.27 /Applications/cmd.app/Contents/MacOS/cmd
    me           29834   0.0  0.0 410463600   9984   ??  Ss    2:52PM   0:00.01 /Applications/cmd.app/Contents/PlugIns/cmd (Debug).appex/Contents/MacOS/command -AppleLanguages ("en-US")
    me           35742   0.0  0.0 410724160   1520 s003  S+    3:08PM   0:00.00 grep --color=auto cmd
    """

  @Test
  func testRequestingAccessibilityPermissions() async throws {
    let exp = expectation(description: "accessibility permission requested")
    let sut = DefaultPermissionsService(
      requestAccessibilityPermission: {
        exp.fulfill()
      },
      requestXcodeExtensionPermission: { })
    sut.request(permission: .accessibility)
    try await fulfillment(of: exp)
  }

  @Test
  func testReadingAccessibilityPermissionsPollUntilPermissionIsGranted() async throws {
    let pollUntilGranted = 5
    let exp = expectation(description: "accessibility permission status granted")
    let pollCount = Atomic(0)

    let sut = DefaultPermissionsService(
      isAccessibilityPermissionGranted: {
        pollCount.increment() >= pollUntilGranted
      },
      requestXcodeExtensionPermission: { })

    let receivedValues = Atomic<[Bool?]>([])
    let cancellable = sut.status(for: .accessibility).sink { value in
      receivedValues.mutate { $0.append(value) }
      if value == true {
        exp.fulfill()
      }
    }
    try await fulfillment(of: exp, timeout: 10) // Large timeout as Task.sleep is not accurate.
    #expect(pollCount.value == pollUntilGranted)
    #expect(receivedValues.value.compactMap(\.self) == [false, true])
    _ = cancellable
  }

  @Test
  func testReadingXcodeExtensionPermissionsPollUntilPermissionIsGranted() async throws {
    let pollUntilGranted = 5
    let exp = expectation(description: "xcode extension permission status granted")
    let pollCount = Atomic(0)

    let shellService = MockShellService()
    shellService.onRun = { command, _, _, _, _ in
      #expect(command == "ps aux | grep 'cmd'")
      let count = pollCount.increment()
      return CommandExecutionResult(
        exitCode: 0,
        stdout: count >= pollUntilGranted ? Self.xcodeExtensionRunningStdout : Self.xcodeExtensionNotRunningStdout,
        stderr: nil)
    }

    let sut = DefaultPermissionsService(shellService: shellService)

    let cancellable = sut.status(for: .xcodeExtension).sink { value in
      if value == true {
        exp.fulfill()
      }
    }
    try await fulfillment(of: exp, timeout: 10) // Large timeout as Task.sleep is not accurate.
    #expect(pollCount.value == pollUntilGranted)
    _ = cancellable
  }

}

extension DefaultPermissionsService {
  convenience init(
    shellService: ShellService = MockShellService(),
    userDefaults: UserDefaults = UserDefaults.standard,
    isAccessibilityPermissionGranted: @escaping @Sendable () -> Bool = { false },
    requestAccessibilityPermission: @escaping @Sendable () -> Void = { },
    requestXcodeExtensionPermission: @escaping @Sendable () -> Void = { })
  {
    self.init(
      shellService: shellService,
      userDefaults: userDefaults,
      bundle: Bundle.main,
      isAccessibilityPermissionGranted: isAccessibilityPermissionGranted,
      requestAccessibilityPermission: requestAccessibilityPermission,
      requestXcodeExtensionPermission: requestXcodeExtensionPermission,
      pollIntervalNS: 1)
  }
}
