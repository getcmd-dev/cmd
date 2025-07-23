import { AsyncStream } from "../asyncStream"

describe("AsyncStream", () => {
	let stream: AsyncStream<number>

	beforeEach(() => {
		stream = new AsyncStream<number>()
	})

	describe("basic functionality", () => {
		it("should be an async iterator", () => {
			expect(stream[Symbol.asyncIterator]).toBeDefined()
			expect(stream[Symbol.asyncIterator]()).toBe(stream)
		})

		it("should yield values synchronously when there are no pending resolvers", async () => {
			stream.yield(1)
			stream.yield(2)
			stream.done()

			const result1 = await stream.next()
			expect(result1).toEqual({ value: 1, done: false })

			const result2 = await stream.next()
			expect(result2).toEqual({ value: 2, done: false })

			const result3 = await stream.next()
			expect(result3).toEqual({ done: true, value: undefined })
		})

		it("should work with for-await-of loops", async () => {
			const values: number[] = []

			// Start consuming
			const consumePromise = (async () => {
				for await (const value of stream) {
					values.push(value)
				}
			})()

			// Yield values asynchronously
			setTimeout(() => stream.yield(1), 10)
			setTimeout(() => stream.yield(2), 20)
			setTimeout(() => stream.yield(3), 30)
			setTimeout(() => stream.done(), 40)

			await consumePromise
			expect(values).toEqual([1, 2, 3])
		})
	})

	describe("queuing behavior", () => {
		it("should queue values when no resolvers are waiting", async () => {
			stream.yield(1)
			stream.yield(2)
			stream.yield(3)

			const result1 = await stream.next()
			expect(result1).toEqual({ value: 1, done: false })

			const result2 = await stream.next()
			expect(result2).toEqual({ value: 2, done: false })

			const result3 = await stream.next()
			expect(result3).toEqual({ value: 3, done: false })
		})

		it("should deliver values immediately when resolvers are waiting", async () => {
			const nextPromise1 = stream.next()
			const nextPromise2 = stream.next()

			stream.yield(1)
			stream.yield(2)

			const result1 = await nextPromise1
			const result2 = await nextPromise2

			expect(result1).toEqual({ value: 1, done: false })
			expect(result2).toEqual({ value: 2, done: false })
		})

		it("should handle mixed queuing and immediate delivery", async () => {
			// Queue some values first
			stream.yield(1)
			stream.yield(2)

			// Get the queued values
			const result1 = await stream.next()
			const result2 = await stream.next()

			expect(result1).toEqual({ value: 1, done: false })
			expect(result2).toEqual({ value: 2, done: false })

			// Now start waiting for values
			const nextPromise = stream.next()

			// Yield a value - should deliver immediately
			stream.yield(3)

			const result3 = await nextPromise
			expect(result3).toEqual({ value: 3, done: false })
		})
	})

	describe("completion behavior", () => {
		it("should return done: true after calling done()", async () => {
			stream.done()

			const result = await stream.next()
			expect(result).toEqual({ done: true, value: undefined })
		})

		it("should return done: true for all subsequent calls after done()", async () => {
			stream.done()

			const result1 = await stream.next()
			const result2 = await stream.next()
			const result3 = await stream.next()

			expect(result1).toEqual({ done: true, value: undefined })
			expect(result2).toEqual({ done: true, value: undefined })
			expect(result3).toEqual({ done: true, value: undefined })
		})

		it("should resolve all pending resolvers when done() is called", async () => {
			const nextPromise1 = stream.next()
			const nextPromise2 = stream.next()
			const nextPromise3 = stream.next()

			stream.done()

			const results = await Promise.all([nextPromise1, nextPromise2, nextPromise3])

			expect(results).toEqual([
				{ done: true, value: undefined },
				{ done: true, value: undefined },
				{ done: true, value: undefined },
			])
		})

		it("should process remaining queued values before done takes effect", async () => {
			stream.yield(1)
			stream.yield(2)
			stream.done()

			const result1 = await stream.next()
			const result2 = await stream.next()
			const result3 = await stream.next()

			expect(result1).toEqual({ value: 1, done: false })
			expect(result2).toEqual({ value: 2, done: false })
			expect(result3).toEqual({ done: true, value: undefined })
		})
	})

	describe("error handling", () => {
		it("should reject pending promises when error() is called", async () => {
			const testError = new Error("Test error")
			const nextPromise = stream.next()

			stream.error(testError)

			await expect(nextPromise).rejects.toBe(testError)
		})

		it("should throw immediately when error() is called with no pending resolvers", () => {
			const testError = new Error("Test error")

			expect(() => stream.error(testError)).toThrow(testError)
		})

		it("should handle multiple pending resolvers with error", async () => {
			const testError = new Error("Test error")
			const nextPromise1 = stream.next()
			const nextPromise2 = stream.next()

			stream.error(testError)

			await expect(nextPromise1).rejects.toBe(testError)

			// The second promise should still be pending since only one error resolver is consumed
			// Yield a value to resolve the second promise
			stream.yield(42)
			const result2 = await nextPromise2
			expect(result2).toEqual({ value: 42, done: false })
		})

		it("should work normally after handling an error", async () => {
			const testError = new Error("Test error")
			const nextPromise = stream.next()

			stream.error(testError)
			await expect(nextPromise).rejects.toBe(testError)

			// Should work normally after error
			stream.yield(42)
			const result = await stream.next()
			expect(result).toEqual({ value: 42, done: false })
		})
	})

	describe("generic type support", () => {
		it("should work with string types", async () => {
			const stringStream = new AsyncStream<string>()

			stringStream.yield("hello")
			stringStream.yield("world")
			stringStream.done()

			const result1 = await stringStream.next()
			const result2 = await stringStream.next()
			const result3 = await stringStream.next()

			expect(result1).toEqual({ value: "hello", done: false })
			expect(result2).toEqual({ value: "world", done: false })
			expect(result3).toEqual({ done: true, value: undefined })
		})

		it("should work with object types", async () => {
			interface TestObject {
				id: number
				name: string
			}

			const objectStream = new AsyncStream<TestObject>()
			const obj1 = { id: 1, name: "test1" }
			const obj2 = { id: 2, name: "test2" }

			objectStream.yield(obj1)
			objectStream.yield(obj2)
			objectStream.done()

			const result1 = await objectStream.next()
			const result2 = await objectStream.next()
			const result3 = await objectStream.next()

			expect(result1).toEqual({ value: obj1, done: false })
			expect(result2).toEqual({ value: obj2, done: false })
			expect(result3).toEqual({ done: true, value: undefined })
		})
	})

	describe("concurrent access", () => {
		it("should handle concurrent next() calls correctly", async () => {
			const promises = [stream.next(), stream.next(), stream.next()]

			// Yield values in reverse order
			setTimeout(() => stream.yield(3), 10)
			setTimeout(() => stream.yield(2), 20)
			setTimeout(() => stream.yield(1), 30)

			const results = await Promise.all(promises)

			// Should get values in the order they were yielded
			expect(results).toEqual([
				{ value: 3, done: false },
				{ value: 2, done: false },
				{ value: 1, done: false },
			])
		})

		it("should handle concurrent yield calls correctly", async () => {
			const values: number[] = []

			// Start consuming
			const consumePromise = (async () => {
				for await (const value of stream) {
					values.push(value)
				}
			})()

			// Yield multiple values concurrently
			setTimeout(() => stream.yield(1), 10)
			setTimeout(() => stream.yield(2), 10)
			setTimeout(() => stream.yield(3), 10)
			setTimeout(() => stream.done(), 50)

			await consumePromise

			// All values should be received (order may vary due to timing)
			expect(values.sort()).toEqual([1, 2, 3])
		})
	})

	describe("edge cases", () => {
		it("should handle yielding values after done() is called", async () => {
			stream.done()

			// The stream still accepts values after done() is called and queues them
			stream.yield(42)

			const result = await stream.next()
			// The stream will return the queued value instead of done
			expect(result).toEqual({ value: 42, done: false })

			// Subsequent calls should return done
			const result2 = await stream.next()
			expect(result2).toEqual({ done: true, value: undefined })
		})

		it("should handle calling done() multiple times", async () => {
			stream.done()
			stream.done()
			stream.done()

			const result = await stream.next()
			expect(result).toEqual({ done: true, value: undefined })
		})

		it("should handle calling error() after done()", () => {
			stream.done()
			const testError = new Error("Test error")

			// Should throw since there are no error resolvers
			expect(() => stream.error(testError)).toThrow(testError)
		})

		it("should handle very large numbers of values", async () => {
			const numValues = 1000
			const expectedValues = Array.from({ length: numValues }, (_, i) => i)

			// Queue all values
			expectedValues.forEach((value) => stream.yield(value))
			stream.done()

			// Consume all values
			const actualValues: number[] = []
			for await (const value of stream) {
				actualValues.push(value)
			}

			expect(actualValues).toEqual(expectedValues)
		})
	})
})
