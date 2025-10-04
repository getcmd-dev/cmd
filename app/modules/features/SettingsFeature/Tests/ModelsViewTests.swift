// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation
import SwiftTesting
import Testing
@testable import SettingsFeature

// MARK: - ModelsViewExtensionTests

struct ModelsViewExtensionTests {

  // MARK: - sorted(by enabled:) Tests

  @Test("sorts models with enabled models first, then by programming rank")
  func test_sortedByEnabled_enabledModelsFirst() {
    let models = [modelA, modelB, modelC]
    let enabledModels = ["model-a", "model-c"] // modelA and modelC are enabled

    let result = models.sorted(by: enabledModels)

    // modelA (rank 3, enabled) should come first
    // modelC (rank 2, enabled) should come second
    // modelB (rank 1, not enabled) should come last
    let expectedOrder = ["model-a": 1, "model-c": 0, "model-b": 2]
    #expect(result == expectedOrder)
  }

  @Test("sorts models by programming rank when none are enabled")
  func test_sortedByEnabled_noneEnabled() {
    let models = [modelA, modelB, modelC]
    let enabledModels = [String]()

    let result = models.sorted(by: enabledModels)

    // Should sort by programming rank: modelB (1), modelC (2), modelA (3)
    let expectedOrder = ["model-b": 0, "model-c": 1, "model-a": 2]
    #expect(result == expectedOrder)
  }

  @Test("sorts models by programming rank when all are enabled")
  func test_sortedByEnabled_allEnabled() {
    let models = [modelA, modelB, modelC]
    let enabledModels = ["model-a", "model-b", "model-c"]

    let result = models.sorted(by: enabledModels)

    // Should sort by programming rank: modelB (1), modelC (2), modelA (3)
    let expectedOrder = ["model-b": 0, "model-c": 1, "model-a": 2]
    #expect(result == expectedOrder)
  }

  @Test("assigns correct indices to sorted models")
  func test_sortedByEnabled_correctIndices() {
    let models = [modelA, modelB]
    let enabledModels = ["model-b"]

    let result = models.sorted(by: enabledModels)

    // modelB is enabled, so comes first (index 0)
    // modelA is not enabled, so comes second (index 1)
    #expect(result["model-b"] == 0)
    #expect(result["model-a"] == 1)
  }

  // MARK: - sorted(respecting initialOrder:) Tests

  @Test("sorts models respecting the provided initial order")
  func test_sortedRespectingInitialOrder_correctOrder() {
    let models = [modelA, modelB, modelC]
    let initialOrder = ["model-c": 0, "model-a": 1, "model-b": 2]

    let result = models.sorted(respecting: initialOrder)

    // Should return models in order: modelC, modelA, modelB
    #expect(result == [modelC, modelA, modelB])
  }

  @Test("places models not in initial order at the end")
  func test_sortedRespectingInitialOrder_missingModelsAtEnd() {
    let models = [modelA, modelB, modelC]
    let initialOrder = ["model-b": 0] // Only modelB has an order

    let result = models.sorted(respecting: initialOrder)

    // modelB should be first, others should follow in their original relative order
    #expect(result[0] == modelB)
    // modelA and modelC should be after modelB, but their relative order is stable
    #expect(result.dropFirst().contains(modelA))
    #expect(result.dropFirst().contains(modelC))
  }

  @Test("handles empty initial order")
  func test_sortedRespectingInitialOrder_emptyOrder() {
    let models = [modelA, modelB, modelC]
    let initialOrder = [String: Int]()

    let result = models.sorted(respecting: initialOrder)

    // Should maintain original order when no initial order is provided
    #expect(result == [modelA, modelB, modelC])
  }

  @Test("handles empty models array")
  func test_sortedRespectingInitialOrder_emptyModels() {
    let models = [AIModel]()
    let initialOrder = ["model-a": 0]

    let result = models.sorted(respecting: initialOrder)

    #expect(result.isEmpty)
  }

  // MARK: - Integration Tests

  @Test("integration test: sort by enabled then respect that order")
  func test_integration_sortByEnabledThenRespectOrder() {
    let models = [modelA, modelB, modelC]
    let enabledModels = ["model-c"]

    // First sort by enabled status
    let initialOrder = models.sorted(by: enabledModels)

    // Then sort respecting that order
    let result = models.sorted(respecting: initialOrder)

    // modelC should be first (enabled), then modelB (rank 1), then modelA (rank 3)
    #expect(result == [modelC, modelB, modelA])
  }

  // MARK: - Test Data

  private let modelA = AIModel(
    name: "Model A",
    slug: "model-a",
    contextSize: 1000,
    maxOutputTokens: 500,
    defaultPricing: nil,
    createdAt: 0,
    rankForProgramming: 3)

  private let modelB = AIModel(
    name: "Model B",
    slug: "model-b",
    contextSize: 2000,
    maxOutputTokens: 1000,
    defaultPricing: nil,
    createdAt: 0,
    rankForProgramming: 1)

  private let modelC = AIModel(
    name: "Model C",
    slug: "model-c",
    contextSize: 3000,
    maxOutputTokens: 1500,
    defaultPricing: nil,
    createdAt: 0,
    rankForProgramming: 2)

}
