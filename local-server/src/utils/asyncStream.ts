export class AsyncStream<T> implements AsyncIterator<T> {
	private queue: T[] = []
	private resolvers: Array<(result: IteratorResult<T>) => void> = []
	private errorResolvers: Array<(error: Error) => void> = []
	private finished = false

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

	[Symbol.asyncIterator](): AsyncIterator<T> {
		return this
	}

	yield(value: T) {
		if (this.resolvers.length > 0) {
			this.resolvers.shift()!({ value, done: false })
			this.errorResolvers.shift()
		} else {
			this.queue.push(value)
		}
	}

	error(error: Error) {
		if (this.errorResolvers.length > 0) {
			this.errorResolvers.shift()!(error)
			this.resolvers.shift()
		} else {
			throw error
		}
	}

	done() {
		this.finished = true
		this.resolvers.forEach((resolve) => resolve({ done: true, value: undefined }))
		this.resolvers.length = 0
		this.errorResolvers.length = 0
	}
}
