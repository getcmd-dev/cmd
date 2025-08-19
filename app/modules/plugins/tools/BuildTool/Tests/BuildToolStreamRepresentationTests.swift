// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
import XcodeControllerServiceInterface
@testable import BuildTool

struct BuildToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let (status, _) = BuildTool.Use.Status.makeStream(initial: .running)

    let viewModel = ToolUseViewModel(
      buildType: .test,
      status: status)

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful test build")
  func test_streamRepresentationSuccessfulTestBuild() {
    // given
    let output = BuildTool.Use.Output(
      buildResult: .init(
        title: "Build",
        messages: [],
        subSections: [],
        duration: 0.5),
      isSuccess: true)
    let (status, _) = BuildTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = ToolUseViewModel(
      buildType: .test,
      status: status)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Build(test)
        ⎿ Succeeded


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failed run build")
  func test_streamRepresentationFailedRunBuild() {
    // given
    let output = BuildTool.Use.Output(
      buildResult: .init(
        title: "Build",
        messages: [
          .init(message: "Compilation failed", severity: .error, location: nil),
        ],
        subSections: [],
        duration: 1.2),
      isSuccess: false)
    let (status, _) = BuildTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = ToolUseViewModel(
      buildType: .run,
      status: status)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Build(run)
        ⎿ Failed


      """)
  }

  @MainActor
  @Test("streamRepresentation shows build tool failure")
  func test_streamRepresentationBuildToolFailure() {
    // given
    let error = AppError("Xcode not found")
    let (status, _) = BuildTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = ToolUseViewModel(
      buildType: .test,
      status: status)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Build(test)
        ⎿ Failed: Xcode not found


      """)
  }

  @MainActor
  @Test("streamRepresentation handles both build types correctly")
  func test_streamRepresentationBuildTypes() {
    // given
    let testOutput = BuildTool.Use.Output(
      buildResult: .init(title: "Test", messages: [], subSections: [], duration: 2.5),
      isSuccess: true)
    let (testStatus, _) = BuildTool.Use.Status.makeStream(initial: .completed(.success(testOutput)))
    let testViewModel = ToolUseViewModel(buildType: .test, status: testStatus)

    let runOutput = BuildTool.Use.Output(
      buildResult: .init(title: "Run", messages: [], subSections: [], duration: 1.8),
      isSuccess: true)
    let (runStatus, _) = BuildTool.Use.Status.makeStream(initial: .completed(.success(runOutput)))
    let runViewModel = ToolUseViewModel(buildType: .run, status: runStatus)

    // then
    #expect(testViewModel.streamRepresentation == """
      ⏺ Build(test)
        ⎿ Succeeded


      """)

    #expect(runViewModel.streamRepresentation == """
      ⏺ Build(run)
        ⎿ Succeeded


      """)
  }
}
