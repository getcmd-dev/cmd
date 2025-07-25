/**
 * Parse a stream of valid JSON objects that are received in chunks,
 * each chunk potentially containing part of a JSON object or multiple JSON objects.
 *
 * This parser maintains internal state to track string boundaries, brace nesting,
 * and escape sequences to properly identify complete JSON objects within a stream.
 *
 * @example
 * ```typescript
 * const parser = new StreamingJsonParser();
 *
 * // Process chunks as they arrive
 * const results1 = parser.processChunk('{"name": "Jo');
 * console.log(results1); // [] - incomplete JSON
 *
 * const results2 = parser.processChunk('hn", "age": 30}{"city": "NYC"}');
 * console.log(results2); // [{name: "John", age: 30}, {city: "NYC"}]
 * ```
 */
export class StreamingJsonParser {
	private buffer = ""
	private braceCount = 0
	private inString = false
	private escaped = false
	private processedIndex = 0 // Track how much we've already processed

	/**
	 * Process a chunk of data and return any complete JSON objects found.
	 *
	 * This method maintains internal state across calls, allowing JSON objects
	 * to be split across multiple chunks. It handles:
	 * - String boundaries (ignoring braces within strings)
	 * - Escape sequences within strings
	 * - Nested objects and arrays
	 * - Multiple complete JSON objects in a single chunk
	 *
	 * @param chunk - The incoming data chunk to process
	 * @returns An array of parsed JSON objects found in this chunk
	 *
	 * @example
	 * ```typescript
	 * const parser = new StreamingJsonParser();
	 * const objects = parser.processChunk('{"id": 1}{"id": 2}');
	 * // Returns: [{id: 1}, {id: 2}]
	 * ```
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
