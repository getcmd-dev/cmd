// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

public struct ModelPricing: Sendable, Codable {
  public init(input: Double, output: Double, cacheWrite: Double, cachedInput: Double, inputImage: Double? = nil) {
    self.input = input
    self.output = output
    self.cacheWrite = cacheWrite
    self.cachedInput = cachedInput
    self.inputImage = inputImage
  }

  public init(input: Double, output: Double, cacheWriteMult: Double, cachedInputMult: Double, inputImage: Double? = nil) {
    self.input = input
    self.output = output
    cacheWrite = input * (1 + cacheWriteMult)
    cachedInput = input * cachedInputMult
    self.inputImage = inputImage
  }

  public let input: Double
  public let output: Double
  public let cacheWrite: Double
  public let cachedInput: Double
  public let inputImage: Double?

}
