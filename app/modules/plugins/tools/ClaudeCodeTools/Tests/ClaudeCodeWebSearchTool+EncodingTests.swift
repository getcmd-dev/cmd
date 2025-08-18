// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation
import Testing
import ToolFoundation
@testable import ClaudeCodeTools

@Suite("ClaudeCodeWebSearchTool Encoding Tests")
struct ClaudeCodeWebSearchToolEncodingTests {

  @Test("Encode and decode Input")
  func testInputCoding() throws {
    let input1 = ClaudeCodeWebSearchTool.Use.Input(
      query: "SwiftUI best practices",
      allowed_domains: ["developer.apple.com", "swift.org"],
      blocked_domains: ["example.com"])

    let encoded = try JSONEncoder().encode(input1)
    let decoded = try JSONDecoder().decode(ClaudeCodeWebSearchTool.Use.Input.self, from: encoded)

    #expect(decoded.query == input1.query)
    #expect(decoded.allowed_domains == input1.allowed_domains)
    #expect(decoded.blocked_domains == input1.blocked_domains)

    // Test with nil optional fields
    let input2 = ClaudeCodeWebSearchTool.Use.Input(
      query: "test query",
      allowed_domains: nil,
      blocked_domains: nil)

    let encoded2 = try JSONEncoder().encode(input2)
    let decoded2 = try JSONDecoder().decode(ClaudeCodeWebSearchTool.Use.Input.self, from: encoded2)

    #expect(decoded2.query == input2.query)
    #expect(decoded2.allowed_domains == nil)
    #expect(decoded2.blocked_domains == nil)
  }

  @Test("Encode and decode Output")
  func testOutputCoding() throws {
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [
        .init(title: "Swift Documentation", url: "https://docs.swift.org"),
        .init(title: "Apple Developer", url: "https://developer.apple.com"),
      ],
      content: "This is the search result content.")

    let encoded = try JSONEncoder().encode(output)
    let decoded = try JSONDecoder().decode(ClaudeCodeWebSearchTool.Use.Output.self, from: encoded)

    #expect(decoded.links.count == output.links.count)
    #expect(decoded.links[0].title == output.links[0].title)
    #expect(decoded.links[0].url == output.links[0].url)
    #expect(decoded.links[1].title == output.links[1].title)
    #expect(decoded.links[1].url == output.links[1].url)
    #expect(decoded.content == output.content)
  }

  @Test("Encode and decode SearchResult")
  func testSearchResultCoding() throws {
    let searchResult = ClaudeCodeWebSearchTool.Use.Output.SearchResult(
      title: "Test Title",
      url: "https://example.com/test")

    let encoded = try JSONEncoder().encode(searchResult)
    let decoded = try JSONDecoder().decode(ClaudeCodeWebSearchTool.Use.Output.SearchResult.self, from: encoded)

    #expect(decoded.title == searchResult.title)
    #expect(decoded.url == searchResult.url)
  }

  @Test("JSON representation of Input")
  func testInputJSON() throws {
    let input = ClaudeCodeWebSearchTool.Use.Input(
      query: "swift concurrency",
      allowed_domains: ["swift.org"],
      blocked_domains: nil)

    let encoded = try JSONEncoder().encode(input)
    let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

    #expect(json?["query"] as? String == "swift concurrency")
    #expect(json?["allowed_domains"] as? [String] == ["swift.org"])
    #expect(json?["blocked_domains"] == nil)
  }

  @Test("JSON representation of Output")
  func testOutputJSON() throws {
    let output = ClaudeCodeWebSearchTool.Use.Output(
      links: [
        .init(title: "Result 1", url: "https://example.com/1"),
      ],
      content: "Test content")

    let encoded = try JSONEncoder().encode(output)
    let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

    #expect(json?["content"] as? String == "Test content")

    let links = json?["links"] as? [[String: String]]
    #expect(links?.count == 1)
    #expect(links?[0]["title"] == "Result 1")
    #expect(links?[0]["url"] == "https://example.com/1")
  }
}
