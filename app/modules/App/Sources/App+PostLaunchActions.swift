// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

//
//  App+PostLaunchActions.swift
//  Packages
//
//  Created by Guigui on 6/4/25.
//
import AppUpdateServiceInterface
import ChatCompletionServiceInterface
import Dependencies
import LoggingServiceInterface
import XcodeObserverServiceInterface

extension commandApp {
  func postLaunchActions() {
    Task {
      // Initialize the local server on launch
      @Dependency(\.localServer) var server
      _ = try? await server.getRequest(path: "launch")
    }
    // Initiate the service to start automatic updates
    @Dependency(\.appUpdateService) var appUpdateService
    _ = appUpdateService
    // Initiate the local HTTP server to support chat completion
    @Dependency(\.chatCompletion) var chatCompletion
    chatCompletion.start()

    // Setup login item for first time if not already enabled
    // Ensure the launch agent is up to date and enabled
    Task {
      do {
        @Dependency(\.userDefaults) var userDefaults
        try await AppLauncherManager(userDefaults: userDefaults).enable()
      } catch {
        defaultLogger.error("Failed to enable launch agent", error)
      }
    }
  }
}
