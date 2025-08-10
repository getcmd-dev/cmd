import { jest } from "@jest/globals"

/**
 * Interface for the mocked file system utilities.
 * Provides Jest mock functions for common fs operations with an in-memory file store.
 */
export interface MockedFs {
	/** Mock function for fs.writeFileSync - writes data to the in-memory file store */
	writeFileSync: jest.MockedFunction<(path: string, data: string) => void>
	/** Mock function for fs.appendFileSync - appends data to existing file or creates new file in the in-memory file store */
	appendFileSync: jest.MockedFunction<(path: string, data: string) => void>
	/** Mock function for fs.readFileSync - reads data from the in-memory file store */
	readFileSync: jest.MockedFunction<(path: string, encoding?: string) => string>
	/** Mock function for fs.existsSync - checks if file exists in the in-memory file store */
	existsSync: jest.MockedFunction<(path: string) => boolean>
	/** Mock function for fs.unlinkSync - removes file from the in-memory file store */
	unlinkSync: jest.MockedFunction<(path: string) => void>
	/** Mock function for fs.mkdirSync - creates directories in the in-memory file store */
	mkdirSync: jest.MockedFunction<(path: string, options?: unknown) => void>
	/** In-memory file store mapping file paths to their content */
	files: { [path: string]: string }
	/** Clears all files from the in-memory store and resets all mock call history */
	restore: () => void
}

/**
 * Creates a comprehensive mock for Node.js fs module functions.
 *
 * This utility provides an in-memory file system that can be used in tests to:
 * - Mock file system operations without touching the real file system
 * - Track calls to fs functions for testing purposes
 * - Simulate file system errors and edge cases
 *
 * @param onMock Optional callback that receives the MockedFs instance for setup
 * @returns Object containing all mocked fs functions for use with jest.unstable_mockModule
 *
 * @example
 * ```typescript
 * let mockedFs: MockedFs
 *
 * beforeAll(() => {
 *   jest.unstable_mockModule("fs", () => mockFs((mocked) => {
 *     mockedFs = mocked
 *   }))
 * })
 *
 * beforeEach(() => {
 *   mockedFs.restore()
 * })
 *
 * it("should write config file", () => {
 *   // Test code that calls fs.writeFileSync
 *   expect(mockedFs.writeFileSync).toHaveBeenCalledWith("config.json", "...")
 *   expect(mockedFs.files["config.json"]).toBe("...")
 * })
 * ```
 */
export const mockFs = (onMock?: (mockedFs: MockedFs) => void) => {
	const files: { [path: string]: string } = {}

	const writeFileSync = jest.fn<(path: string, data: string) => void>((path, data) => {
		files[path] = data
	})

	const appendFileSync = jest.fn<(path: string, data: string) => void>((path, data) => {
		if (path in files) {
			files[path] += data
		} else {
			files[path] = data
		}
	})

	const readFileSync = jest.fn<(path: string, encoding?: string) => string>((path) => {
		if (!(path in files)) {
			throw new Error(`ENOENT: no such file or directory, open '${path}'`)
		}
		return files[path]
	})

	const existsSync = jest.fn<(path: string) => boolean>((path) => {
		return path in files
	})

	const unlinkSync = jest.fn<(path: string) => void>((path) => {
		if (!(path in files)) {
			throw new Error(`ENOENT: no such file or directory, unlink '${path}'`)
		}
		delete files[path]
	})

	const mkdirSync = jest.fn<(path: string, options?: unknown) => void>(() => {
		// Simple mock implementation - just track that it was called
		// In real usage, directories would be created, but for our mock we just track the call
	})

	const restore = () => {
		// Clear all files
		Object.keys(files).forEach((key) => delete files[key])

		// Clear all mock call history
		writeFileSync.mockClear()
		appendFileSync.mockClear()
		readFileSync.mockClear()
		existsSync.mockClear()
		unlinkSync.mockClear()
		mkdirSync.mockClear()
	}

	const mockedFs: MockedFs = {
		writeFileSync,
		appendFileSync,
		readFileSync,
		existsSync,
		unlinkSync,
		mkdirSync,
		files,
		restore,
	}

	if (onMock) {
		onMock(mockedFs)
	}

	return {
		writeFileSync,
		appendFileSync,
		readFileSync,
		existsSync,
		unlinkSync,
		mkdirSync,
	}
}
