/**
 * Parse a stream of valid JSON objects that are received in chunks,
 * each chunk potentially containing part of a JSON object or multiple JSON objects.
 */
export class StreamingJsonParser {
	private buffer = ""
	private braceCount = 0
	private inString = false
	private escaped = false
	private processedIndex = 0 // Track how much we've already processed

	/**
	 * Process a chunk of data and return any complete JSON objects found
	 */
	processChunk(chunk: string): unknown[] {
		const results: unknown[] = []
		this.buffer += chunk

		// Only process from where we left off
		for (let i = this.processedIndex; i < this.buffer.length; i++) {
			const char = this.buffer[i]

			// Handle string state tracking
			if (char === '"' && !this.escaped) {
				this.inString = !this.inString
			}

			this.escaped = char === "\\" && !this.escaped

			// Only count braces when not inside a string
			if (!this.inString) {
				if (char === "{") {
					this.braceCount++
				} else if (char === "}") {
					this.braceCount--

					if (this.braceCount === 0) {
						// We have a complete JSON object from start of buffer to current position
						const jsonStr = this.buffer.substring(0, i + 1)
						try {
							const parsed = JSON.parse(jsonStr)
							results.push(parsed)
						} catch (error) {
							console.warn("Failed to parse JSON:", jsonStr, error)
						}

						// Remove processed JSON from buffer and reset tracking
						this.buffer = this.buffer.substring(i + 1)
						this.processedIndex = 0
						i = -1 // Reset loop since buffer changed

						// Reset parser state for next JSON object
						this.inString = false
						this.escaped = false
					}
				}
			}
		}

		// Update processed index to current buffer length
		this.processedIndex = this.buffer.length
		return results
	}
}
