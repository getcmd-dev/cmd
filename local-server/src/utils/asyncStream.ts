/**
 * An async stream implementation that allows yielding values asynchronously.
 * This class implements AsyncIterator and can be used with for-await-of loops.
 *
 * @template T The type of values yielded by the stream
 *
 * @example
 * ```typescript
 * const stream = new AsyncStream<number>();
 *
 * // Producer
 * setTimeout(() => stream.yield(1), 100);
 * setTimeout(() => stream.yield(2), 200);
 * setTimeout(() => stream.done(), 300);
 *
 * // Consumer
 * for await (const value of stream) {
 *   console.log(value); // 1, 2
 * }
 * ```
 */
export class AsyncStream<T> implements AsyncIterator<T> {
	private queue: T[] = []
	private resolvers: Array<(result: IteratorResult<T>) => void> = []
	private errorResolvers: Array<(error: Error) => void> = []
	private finished = false

	/**
	 * Gets the next value from the stream.
	 * If values are queued, returns the next queued value immediately.
	 * If the stream is finished, returns a done result.
	 * Otherwise, returns a promise that resolves when the next value is yielded.
	 *
	 * @returns A promise that resolves to an IteratorResult<T>
	 */
	async next(): Promise<IteratorResult<T>> {
		if (this.queue.length > 0) {
			return { value: this.queue.shift()!, done: false }
		}

		if (this.finished) {
			return { done: true, value: undefined }
		}

		return new Promise<IteratorResult<T>>((resolve, reject) => {
			this.resolvers.push(resolve)
			this.errorResolvers.push(reject)
		})
	}

	/**
	 * Makes this stream async iterable, allowing it to be used with for-await-of loops.
	 *
	 * @returns This AsyncStream instance as an AsyncIterator
	 */
	[Symbol.asyncIterator](): AsyncIterator<T> {
		return this
	}

	/**
	 * Yields a value to the stream.
	 * If there are pending resolvers waiting for values, the value is delivered immediately.
	 * Otherwise, the value is queued for later consumption.
	 *
	 * @param value The value to yield to the stream
	 */
	yield(value: T) {
		if (this.resolvers.length > 0) {
			this.resolvers.shift()!({ value, done: false })
			this.errorResolvers.shift()
		} else {
			this.queue.push(value)
		}
	}

	/**
	 * Signals an error to the stream.
	 * If there are pending error resolvers waiting, the error is delivered to them.
	 * Otherwise, the error is thrown immediately.
	 *
	 * @param error The error to signal
	 * @throws The provided error if no error resolvers are waiting
	 */
	error(error: Error) {
		if (this.errorResolvers.length > 0) {
			this.errorResolvers.shift()!(error)
			this.resolvers.shift()
		} else {
			throw error
		}
	}

	/**
	 * Marks the stream as finished.
	 * All pending resolvers will receive a done result, and future calls to next()
	 * will immediately return done results.
	 */
	done() {
		this.finished = true
		this.resolvers.forEach((resolve) => resolve({ done: true, value: undefined }))
		this.resolvers.length = 0
		this.errorResolvers.length = 0
	}
}
