/**
 * Mock implementation of Express Response object for testing purposes.
 *
 * This utility provides a lightweight mock of the Express Response interface that can be used in tests to:
 * - Capture data written to the response stream
 * - Track headers set on the response
 * - Simulate HTTP response behavior without a real HTTP server
 *
 * @example
 * ```typescript
 * import { MockResponse } from "@/utils/tests/mockResponse"
 *
 * it("should write data to response", async () => {
 *   const mockRes = new MockResponse()
 *
 *   // Code that writes to the response
 *   someFunction(mockRes as unknown as Response)
 *
 *   expect(mockRes.writtenData).toEqual(["chunk1", "chunk2"])
 *   expect(mockRes.headers["content-type"]).toBe("application/json")
 * })
 * ```
 */
export class MockResponse {
	/**
	 * Writes data to the mock response. Data is stored in writtenData array.
	 * @param data - The data to write to the response
	 */
	public write = (data: string) => {
		this._writtenData.push(data)
	}

	/**
	 * Mock implementation of response.end(). Does nothing but can be used to track when response ends.
	 */
	public end = () => {}

	/**
	 * Mock implementation of response.on() for event handling.
	 * Stores event listeners but doesn't trigger them.
	 * @param event - Event name (e.g., 'close', 'error')
	 * @param listener - Event listener function
	 */
	public on = (event: string, listener: (value: unknown | undefined) => void) => {
		if (!this._eventListeners[event]) {
			this._eventListeners[event] = []
		}
		this._eventListeners[event].push(listener)
	}

	/**
	 * Internal storage for written data
	 */
	private _writtenData: string[] = []

	/**
	 * Internal storage for event listeners
	 */
	private _eventListeners: { [event: string]: ((value: unknown | undefined) => void)[] } = {}

	/**
	 * Gets all data that has been written to this mock response.
	 * @returns Array of strings representing all data chunks written to the response
	 */
	public get writtenData() {
		return this._writtenData
	}

	/**
	 * Sets a header on the mock response.
	 * @param key - Header name
	 * @param value - Header value
	 * @returns This MockResponse instance for method chaining
	 */
	public setHeader = (key: string, value: string) => {
		this._headers[key] = value
		return this
	}

	/**
	 * Gets a header value from the mock response.
	 * @param key - Header name
	 * @returns Header value or undefined if not set
	 */
	public getHeader = (key: string) => {
		return this._headers[key]
	}

	/**
	 * Internal storage for response headers
	 */
	private _headers: { [key: string]: string } = {}

	/**
	 * Gets all headers that have been set on this mock response.
	 * @returns Object containing all headers as key-value pairs
	 */
	public get headers(): { [key: string]: string } {
		return this._headers
	}

	/**
	 * Clears all written data, headers, and event listeners from this mock response.
	 * Useful for resetting state between tests.
	 */
	public reset = () => {
		this._writtenData = []
		this._headers = {}
		this._eventListeners = {}
	}

	/**
	 * Triggers an event on this mock response.
	 * Useful for testing event handling behavior.
	 * @param event - Event name to trigger
	 * @param args - Arguments to pass to event listeners
	 */
	public emit = (event: string, ...args: unknown[]) => {
		if (this._eventListeners[event]) {
			this._eventListeners[event].forEach((listener) => listener(...(args as [unknown | undefined])))
		}
	}
}
