import { Options, Query, SDKMessage, SDKUserMessage } from "@anthropic-ai/claude-code"
import { jest } from "@jest/globals"

export type MockedQuery = Query & {
	sendEvent: (event: SDKMessage) => void
	end(): void
}

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

export const mockQuery = (onMock: MockQueryCallback) => {
	jest.unstable_mockModule("@anthropic-ai/claude-code", () => ({
		query: ({ prompt, options }: { prompt: string | AsyncIterable<SDKUserMessage>; options?: Options }): Query => {
			const mock = mockClaudeCodeSDKOnce({ prompt, options })
			onMock(mock, { prompt, options })
			return mock
		},
	}))
}

class PushableAsyncGenerator<T> {
	private pushQueue: T[] = []
	private pullQueue: ((value: IteratorResult<T>) => void)[] = []
	private finished = false

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

	end(): void {
		this.finished = true
		while (this.pullQueue.length > 0) {
			const resolve = this.pullQueue.shift()!
			resolve({ value: undefined, done: true })
		}
	}

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
