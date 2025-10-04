## Instructions
Note: you might see existing code that doesn't follow the patterns described here. Do not restructure this pre-existing code unless specifically instructed.

### Tests
- Use Swift Testing, never use XCTest
- To run tests, prefer to use `./cmd.sh test:swift`, or to run tests for a single module: `./cmd.sh test:swift --module LLMService`. (./cmd.sh is to be run from the root of this repo, ie at `../` from this file's location)
- When editing tests, you should ALWAYS make sure the tests for the corresponding module run.
- When testing JSON payloads, be sure to look at the `JSONTestHelpers`
- When testing async code, use the `expectaction` from `SwiftTesting`
- When testing @Observable objects, use `wait` from `Observable+onChange` of helpers from `Observable+helpers.swift`
- When working with a class that has dependencies:
  * always import `DependenciesTestSupport`. This will ensure each test is injected with isolated dependencies.
  * When relevant, prefer to define and use a helper to set default dependencies on the test suite:
```swift
@Suite("LLMSettingsViewModelTests", .dependencies { $0.setDefaultMockValues() }) { ... }
extension DependencyValues {
  fileprivate mutating func setDefaultMockValues() {
    llmService = MockLLMService()
    settingsService = MockSettingsService()
  }
}
```
  * When setting **initial** properties for a dependency to use the syntax
```swift
@Test("some test", .dependencies {
  $0.llmService = MockLLMService(availableModels: [...])
})
```
over using `withDependencies` within the function code.
  * When stubbing method calls, or needing to access the dependency within the test function, do this as so:
```swift
@Test("some test", .dependencies {
  $0.llmService = MockLLMService(availableModels: [...])
})
func something() async throws {
  @Dependency(\.llmService) var llmService
  let mockLLMService = try #require(llmService as? MockLLMService)
  mockLLMService.onFetchModels = ...
}
```
- Never use force unwrapping. Either use `try #require(...)` or `guard` / `throw`.

## Coding style
### Tests
- Whenever possible, use `sut` (system under test) to name the object being tested.
- Try to organize each test with given/when/then sections, marked by comments ex:
```swift
@MainActor @Test("Is not called when a non-observed property changes")
    func didSet_isNotCalledWhenNonObservedPropertyChanges() async throws {
      // given
      let sut = ObservableValue(int: 1)
      let receivedValues = Atomic<[Int]>([])
      let cancellable: Cancellable? = sut.didSet(\.int, perform: { newValue in
        Issue.record("didSet should not be called")
        receivedValues.mutate { $0.append(newValue) }
      })
      _ = cancellable

      // when
      sut.structValue.string = "foo"
      await nextTick()

      // then
      #expect(receivedValues.value == [])
    }
  }
```
- Since you're using `@Test`, function names do not need to start with `test_`
