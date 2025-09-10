/**
 * JSONL (JSON Lines) utility for parsing newline-delimited JSON data.
 * Each line should contain a valid JSON object or array.
 */
export const JSONL = {
	parse: parseJSONL,
}

/**
 * Parses JSONL (JSON Lines) format content into an array of objects.
 * Handles nested objects/arrays and properly escapes strings.
 *
 * @param content - The JSONL content as a string
 * @returns An array of parsed JSON objects
 *
 * @example
 * ```typescript
 * const content = '{"name": "John"}\n{"age": 30}\n{"city": "NYC"}';
 * const results = parseJSONL(content);
 * // Returns: [{"name": "John"}, {"age": 30}, {"city": "NYC"}]
 * ```
 */
function parseJSONL(content: string): unknown[] {
	const results: unknown[] = []
	let current = ""
	let depth = 0
	let inString = false
	let escape = false

	for (let i = 0; i < content.length; i++) {
		const char = content[i]
		current += char

		if (escape) {
			escape = false
			continue
		}

		if (char === "\\") {
			escape = true
			continue
		}

		if (char === '"') {
			inString = !inString
			continue
		}

		if (!inString) {
			if (char === "{" || char === "[") depth++
			else if (char === "}" || char === "]") depth--

			// When depth returns to 0 and we hit a newline, we have a complete object
			if (depth === 0 && char === "\n") {
				const trimmed = current.trim()
				if (trimmed) {
					try {
						results.push(JSON.parse(trimmed))
					} catch (e) {
						throw new Error(`Parse error: ${e}`)
					}
				}
				// Reset buffer at end of line regardless of parse success
				current = ""
			}
		}
	}

	// Don't forget the last object if file doesn't end with newline
	if (current.trim()) {
		try {
			results.push(JSON.parse(current.trim()))
		} catch (e) {
			throw new Error(`Parse error for last object: ${e}`)
		}
	}

	return results
}
