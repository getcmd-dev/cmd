import { ChildProcess } from "child_process"
import { Duplex } from "stream"
import { EventEmitter } from "events"
import { jest } from "@jest/globals"

/**
 * Extended ChildProcess interface with guaranteed stream properties for testing.
 */
export type MockedSpawn = ChildProcess & {
	stdin: Duplex
	stdout: Duplex
	stderr: Duplex
}

/**
 * Mock spawn callback function that receives the spawned process and spawn arguments.
 */
export type MockSpawnCallback = (process: MockedSpawn, command: string, args: string[]) => void

/**
 * Custom Duplex stream implementation for testing that maintains an internal buffer.
 * Useful for simulating stdin/stdout/stderr interactions in child processes.
 */
class StringDuplex extends Duplex {
	private buffer: string = ""

	constructor() {
		super()
	}

	_read(size: number) {
		if (this.buffer.length > 0) {
			const chunk = this.buffer.slice(0, size)
			this.buffer = this.buffer.slice(size)
			this.push(chunk)
		} else {
			this.push(null) // No data to read
		}
	}

	_write(chunk: string, encoding: string, callback: () => void) {
		this.buffer += chunk.toString()
		this.emit("data", chunk.toString())
		callback()
	}
}

/**
 * Creates a single mock spawn instance with the given command and arguments.
 *
 * @param command - The command that would be executed
 * @param args - The arguments passed to the command
 * @returns MockedSpawn instance with mocked stdin/stdout/stderr streams
 */
const mockSpawnOnce = (_command: string, _args: string[]): MockedSpawn => {
	const proc = <MockedSpawn>new EventEmitter()

	proc.stdin = new StringDuplex()
	proc.stdout = new StringDuplex()
	proc.stderr = new StringDuplex()

	return proc
}

/**
 * Creates a comprehensive mock for Node.js child_process.spawn function.
 *
 * This utility provides a mock child process that can be used in tests to:
 * - Mock process spawning without actually starting real processes
 * - Track spawn calls with command and arguments for testing purposes
 * - Simulate process stdin/stdout/stderr interactions
 * - Simulate process events like 'close', 'error', etc.
 *
 * @param onMock Callback function that receives the mocked process, command, and args for each spawn call
 *
 * @example
 * ```typescript
 * let spawned: MockedSpawn
 * let spawnCommand: string
 * let spawnArgs: string[]
 *
 * beforeAll(() => {
 *   mockSpawn((process, command, args) => {
 *     spawned = process
 *     spawnCommand = command
 *     spawnArgs = args
 *   })
 * })
 *
 * it("should spawn claude with correct arguments", async () => {
 *   // Test code that calls spawn
 *   expect(spawnCommand).toBe("/usr/local/bin/claude")
 *   expect(spawnArgs).toContain("--output-format")
 *
 *   // Simulate process output
 *   spawned.stdout.write("some output")
 *   spawned.emit("close", 0)
 * })
 * ```
 */
export const mockSpawn = (onMock: MockSpawnCallback) => {
	jest.unstable_mockModule("child_process", () => ({
		spawn: (command: string, args: string[]) => {
			const proc = mockSpawnOnce(command, args)
			onMock(proc, command, args)
			return proc
		},
	}))
}
