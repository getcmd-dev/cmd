
## Coding style
### Tests
Whenever possible, use `sut` (system under test) to name the object being tested.
Try to organize each test with given/when/then sections, marked by comments ex:
```swift
@MainActor @Test("Is not called when a non-observed property changes")
    func test_didSet_isNotCalledWhenNonObservedPropertyChanges() async throws {
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
