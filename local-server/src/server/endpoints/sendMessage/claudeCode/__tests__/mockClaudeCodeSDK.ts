import { Options, Query, SDKMessage, SDKUserMessage } from "@anthropic-ai/claude-code"
import { jest } from "@jest/globals"

/**
 * Extended Query interface with additional testing methods for event simulation.
 */
export type MockedQuery = Query & {
	sendEvent: (event: SDKMessage) => void
	end(): void
}

/**
 * Mock query callback function that receives the mocked query instance and query parameters.
 */
export type MockQueryCallback = (
	query: MockedQuery,
	{
		prompt,
		options,
	}: {
		prompt: string | AsyncIterable<SDKUserMessage>
		options?: Options
	},
) => void

/**
 * Creates a single mock Claude Code SDK query instance with the given prompt and options.
 *
 * @param prompt - The prompt string or async iterable of user messages
 * @param options - Optional configuration for the query
 * @returns MockedQuery instance with mocked SDK methods and event streaming
 */
const mockClaudeCodeSDKOnce = ({
	prompt,
	options,
}: {
	prompt: string | AsyncIterable<SDKUserMessage>
	options?: Options
}): MockedQuery => {
	const mock = <MockedQuery & PushableAsyncGenerator<SDKMessage>>(new PushableAsyncGenerator<SDKMessage>() as unknown)
	mock.interrupt = () => Promise.resolve()
	mock.setPermissionMode = () => Promise.resolve()
	mock.setModel = () => Promise.resolve()
	mock.supportedCommands = () => Promise.resolve([])
	mock.supportedModels = () => Promise.resolve([])

	mock.sendEvent = (event: SDKMessage) => {
		mock.push(event)
	}

	return mock
}

/**
 * Creates a comprehensive mock for the Claude Code SDK query function.
 *
 * This utility provides a mock Claude Code SDK that can be used in tests to:
 * - Mock SDK queries without making actual API calls
 * - Track query calls with prompt and options for testing purposes
 * - Simulate SDK message streaming and event handling
 * - Test query lifecycle methods like interrupt, setPermissionMode, etc.
 *
 * @param onMock Callback function that receives the mocked query, prompt, and options for each query call
 *
 * @example
 * ```typescript
 * let mockQuery: MockedQuery
 * let queryPrompt: string | AsyncIterable<SDKUserMessage>
 * let queryOptions: Options | undefined
 *
 * beforeAll(() => {
 *   mockQuery((query, { prompt, options }) => {
 *     mockQuery = query
 *     queryPrompt = prompt
 *     queryOptions = options
 *   })
 * })
 *
 * it("should query Claude Code SDK with correct parameters", async () => {
 *   // Test code that calls the SDK query function
 *   expect(queryPrompt).toBe("Hello Claude")
 *   expect(queryOptions?.model).toBe("claude-3-opus")
 *
 *   // Simulate SDK response
 *   mockQuery.sendEvent({ type: "message", content: "Hello!" })
 *   mockQuery.end()
 * })
 * ```
 */
export const mockQuery = (onMock: MockQueryCallback) => {
	jest.unstable_mockModule("@anthropic-ai/claude-code", () => ({
		query: ({ prompt, options }: { prompt: string | AsyncIterable<SDKUserMessage>; options?: Options }): Query => {
			const mock = mockClaudeCodeSDKOnce({ prompt, options })
			onMock(mock, { prompt, options })
			return mock
		},
	}))
}

/**
 * Custom async generator implementation that allows pushing values and controlling iteration flow.
 * Used to simulate streaming SDK messages in tests where we need to control when messages are emitted.
 */
class PushableAsyncGenerator<T> {
	private pushQueue: T[] = []
	private pullQueue: ((value: IteratorResult<T>) => void)[] = []
	private finished = false

	/**
	 * Pushes a value to the generator, making it available for iteration.
	 * @param value The value to push to the generator
	 */
	push(value: T): void {
		if (this.finished) {
			throw new Error("Generator already finished")
		}

		if (this.pullQueue.length > 0) {
			const resolve = this.pullQueue.shift()!
			resolve({ value, done: false })
		} else {
			this.pushQueue.push(value)
		}
	}

	/**
	 * Signals the end of the generator, resolving any pending iterations.
	 */
	end(): void {
		this.finished = true
		while (this.pullQueue.length > 0) {
			const resolve = this.pullQueue.shift()!
			resolve({ value: undefined, done: true })
		}
	}

	/**
	 * Async iterator implementation that yields pushed values in order.
	 * Waits for new values if none are available and the generator isn't finished.
	 */
	async *[Symbol.asyncIterator](): AsyncGenerator<T> {
		while (true) {
			if (this.pushQueue.length > 0) {
				yield this.pushQueue.shift()!
			} else if (this.finished) {
				return
			} else {
				// Wait for next push
				const result = await new Promise<IteratorResult<T>>((resolve) => {
					this.pullQueue.push(resolve)
				})
				if (result.done) return
				yield result.value
			}
		}
	}
}
