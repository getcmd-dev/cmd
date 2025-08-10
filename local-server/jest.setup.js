import { jest } from "@jest/globals"
import { TextEncoder, TextDecoder } from "util"
import { ReadableStream } from "stream/web"
import { fileURLToPath } from "url"
import { dirname } from "path"
import { toMatchFile } from "jest-file-snapshot"
import { expect } from "@jest/globals"

expect.extend({ toMatchFile })

// ESM dirname polyfill
globalThis.__dirname = dirname(fileURLToPath(import.meta.url))

// Polyfill for TextEncoder/TextDecoder
globalThis.TextEncoder = TextEncoder
globalThis.TextDecoder = TextDecoder

// Polyfill for ReadableStream if needed
if (typeof ReadableStream === "undefined") {
	globalThis.ReadableStream = ReadableStream
}
process.env.JEST_WORKER_ID = process.env.JEST_WORKER_ID || "0"

// Mock fetch globally
globalThis.fetch = jest.fn()
