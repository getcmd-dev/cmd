// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import AskFollowUpTool

extension AskFollowUpToolTests {

  struct StreamRepresentationTests {
    @MainActor
    @Test("streamRepresentation returns nil when status is not completed")
    func test_streamRepresentationNilWhenNotCompleted() {
      let (status, _) = AskFollowUpTool.Use.Status.makeStream(initial: .running)

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(question: "What should we do next?", followUp: ["Option 1", "Option 2"]),
        selectFollowUp: { _ in })

      #expect(viewModel.streamRepresentation == nil)
    }

    @MainActor
    @Test("streamRepresentation shows success with follow-up count")
    func test_streamRepresentationSuccess() {
      // given
      let output = AskFollowUpTool.Use.Output(response: "Please choose from the options")
      let (status, _) = AskFollowUpTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(question: "What should we do next?", followUp: ["Option 1", "Option 2", "Option 3"]),
        selectFollowUp: { _ in })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Ask(What should we do next?)
          ⎿ 3 follow-up options provided


        """)
    }

    @MainActor
    @Test("streamRepresentation shows success with no follow-up options")
    func test_streamRepresentationSuccessWithNoOptions() {
      // given
      let output = AskFollowUpTool.Use.Output(response: "Direct answer")
      let (status, _) = AskFollowUpTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(question: "Simple question?", followUp: []),
        selectFollowUp: { _ in })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Ask(Simple question?)
          ⎿ 0 follow-up options provided


        """)
    }

    @MainActor
    @Test("streamRepresentation shows failure with error")
    func test_streamRepresentationFailure() {
      // given
      let error = AppError("Unable to process question")
      let (status, _) = AskFollowUpTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(question: "Complex question?", followUp: ["A", "B"]),
        selectFollowUp: { _ in })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Ask(Complex question?)
          ⎿ Failed: Unable to process question


        """)
    }

    @MainActor
    @Test("streamRepresentation handles long question text")
    func test_streamRepresentationWithLongQuestion() {
      // given
      let longQuestion = "This is a very long question that contains multiple sentences and detailed context about what we're trying to accomplish?"
      let output = AskFollowUpTool.Use.Output(response: "Response to long question")
      let (status, _) = AskFollowUpTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(question: longQuestion, followUp: ["Yes", "No", "Maybe"]),
        selectFollowUp: { _ in })

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Ask(\(longQuestion))
          ⎿ 3 follow-up options provided


        """)
    }
  }
}
