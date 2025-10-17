// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import SwiftTesting
import Testing
@testable import ToolFoundation

// MARK: - ToolsPluginTests

@Suite("ToolsPluginTests")
struct ToolsPluginTests {

  // MARK: - tools(withReferenceIds:)

  @Test("tools(withReferenceIds:) returns tools matching the specified reference IDs")
  func toolsWithReferenceIds_returnsMatchingTools() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1")
    let tool2 = TestTool(name: "Tool2")
    let tool3 = TestTool(name: "Tool3")

    sut.plugIn(tool: tool1)
    sut.plugIn(tool: tool2)
    sut.plugIn(tool: tool3)

    // when
    let result = sut.tools(withReferenceIds: ["Tool1", "Tool3"])

    // then
    #expect(result.count == 2)
    #expect(result.contains { $0.id == "Tool1" })
    #expect(result.contains { $0.id == "Tool3" })
    #expect(!result.contains { $0.id == "Tool2" })
  }

  @Test("tools(withReferenceIds:) returns empty array when no IDs match")
  func toolsWithReferenceIds_returnsEmptyArrayWhenNoMatch() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1")
    let tool2 = TestTool(name: "Tool2")

    sut.plugIn(tool: tool1)
    sut.plugIn(tool: tool2)

    // when
    let result = sut.tools(withReferenceIds: ["NonExistent1", "NonExistent2"])

    // then
    #expect(result.isEmpty)
  }

  @Test("tools(withReferenceIds:) returns empty array when given empty array")
  func toolsWithReferenceIds_returnsEmptyArrayForEmptyInput() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1")

    sut.plugIn(tool: tool1)

    // when
    let result = sut.tools(withReferenceIds: [])

    // then
    #expect(result.isEmpty)
  }

  @Test("tools(withReferenceIds:) returns partial matches when some IDs exist")
  func toolsWithReferenceIds_returnsPartialMatches() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1")
    let tool2 = TestTool(name: "Tool2")

    sut.plugIn(tool: tool1)
    sut.plugIn(tool: tool2)

    // when
    let result = sut.tools(withReferenceIds: ["Tool1", "NonExistent", "Tool2"])

    // then
    #expect(result.count == 2)
    #expect(result.contains { $0.id == "Tool1" })
    #expect(result.contains { $0.id == "Tool2" })
  }

  @Test("tools(withReferenceIds:) returns all matching tools")
  func toolsWithReferenceIds_returnsAllMatchingTools() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1")
    let tool2 = TestTool(name: "Tool2")
    let tool3 = TestTool(name: "Tool3")

    sut.plugIn(tool: tool1)
    sut.plugIn(tool: tool2)
    sut.plugIn(tool: tool3)

    // when
    let result = sut.tools(withReferenceIds: ["Tool3", "Tool1", "Tool2"])

    // then
    #expect(result.count == 3)
    let resultIds = Set(result.map(\.id))
    #expect(resultIds == Set(["Tool1", "Tool2", "Tool3"]))
  }

  // MARK: - defaultTools(for:)

  @Test("defaultTools(for:) returns tools available by default for agent mode")
  func defaultTools_returnsToolsAvailableInAgentMode() {
    // given
    let sut = ToolsPlugin()
    let agentTool = TestTool(name: "AgentTool", availableByDefaultIn: [.agent])
    let askTool = TestTool(name: "AskTool", availableByDefaultIn: [.ask])
    let bothTool = TestTool(name: "BothTool", availableByDefaultIn: [.agent, .ask])

    sut.plugIn(tool: agentTool)
    sut.plugIn(tool: askTool)
    sut.plugIn(tool: bothTool)

    // when
    let result = sut.defaultTools(for: .agent)

    // then
    #expect(result.count == 2)
    #expect(result.contains { $0.id == "AgentTool" })
    #expect(result.contains { $0.id == "BothTool" })
    #expect(!result.contains { $0.id == "AskTool" })
  }

  @Test("defaultTools(for:) returns tools available by default for ask mode")
  func defaultTools_returnsToolsAvailableInAskMode() {
    // given
    let sut = ToolsPlugin()
    let agentTool = TestTool(name: "AgentTool", availableByDefaultIn: [.agent])
    let askTool = TestTool(name: "AskTool", availableByDefaultIn: [.ask])
    let bothTool = TestTool(name: "BothTool", availableByDefaultIn: [.agent, .ask])

    sut.plugIn(tool: agentTool)
    sut.plugIn(tool: askTool)
    sut.plugIn(tool: bothTool)

    // when
    let result = sut.defaultTools(for: .ask)

    // then
    #expect(result.count == 2)
    #expect(result.contains { $0.id == "AskTool" })
    #expect(result.contains { $0.id == "BothTool" })
    #expect(!result.contains { $0.id == "AgentTool" })
  }

  @Test("defaultTools(for:) returns empty array when no tools are available for mode")
  func defaultTools_returnsEmptyArrayWhenNoToolsAvailable() {
    // given
    let sut = ToolsPlugin()
    let agentOnlyTool = TestTool(name: "AgentOnlyTool", availableByDefaultIn: [.agent])

    sut.plugIn(tool: agentOnlyTool)

    // when
    let result = sut.defaultTools(for: .ask)

    // then
    #expect(result.isEmpty)
  }

  @Test("defaultTools(for:) returns all tools when all are available by default")
  func defaultTools_returnsAllToolsWhenAllAvailable() {
    // given
    let sut = ToolsPlugin()
    let tool1 = TestTool(name: "Tool1", availableByDefaultIn: [.agent, .ask])
    let tool2 = TestTool(name: "Tool2", availableByDefaultIn: [.agent, .ask])
    let tool3 = TestTool(name: "Tool3", availableByDefaultIn: [.agent, .ask])

    sut.plugIn(tool: tool1)
    sut.plugIn(tool: tool2)
    sut.plugIn(tool: tool3)

    // when
    let result = sut.defaultTools(for: .agent)

    // then
    #expect(result.count == 3)
  }

  @Test("defaultTools(for:) returns empty array when plugin has no tools")
  func defaultTools_returnsEmptyArrayWhenNoToolsRegistered() {
    // given
    let sut = ToolsPlugin()

    // when
    let result = sut.defaultTools(for: .agent)

    // then
    #expect(result.isEmpty)
  }
}
