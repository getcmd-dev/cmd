import { describe, expect, beforeEach } from "@jest/globals"
import { Router } from "express"
import express from "express"
import request, { Response } from "supertest"
import wsRequest from "superwstest"
import { registerEndpoint, startInterProcessesBridge, ExecuteCommandRequest } from "../interProcessesBridge"
import http from "http"
import { WebSocket } from "ws"

describe("InterProcessesBridge", () => {
	let app: express.Application
	let server: http.Server

	beforeEach((done) => {
		// Create Express app
		app = express()
		app.use(express.json())

		// Register the endpoints
		const router = Router()
		registerEndpoint(router)
		app.use(router)
		server = app.listen(0, () => {
			done()
		})
		startInterProcessesBridge(server)
	})

	afterEach((done) => {
		server.close(() => {
			done()
		})
	})

	it("returns 404 if the host app is not connected", async () => {
		const response = await request(app).post("/execute-command").send({
			type: "execute-command",
			command: "hello",
			input: {},
		})
		expect(response.status).toBe(404)
		expect(response.body).toEqual({ type: "error", error: "No connection to host app", data: undefined })
	})

	describe("when the host app is connected", () => {
		let ws: WebSocket
		let data: string | undefined
		let error: string | undefined
		beforeEach(async () => {
			// Setup the Websocket connection from the host app.
			ws = await wsRequest(server).ws("")
			ws.on("message", (messageBuffer: Buffer) => {
				const message = JSON.parse(messageBuffer.toString("utf-8")) as ExecuteCommandRequest & { id: string }

				expect(message).toEqual({
					type: "execute-command",
					command: "hello",
					input: {},
					id: expect.any(String),
				})

				ws.send(
					JSON.stringify({
						type: "command-response",
						data: data,
						error: error,
						id: message.id,
					}),
				)
			})
		})

		afterEach(() => {
			data = undefined
			error = undefined
			ws.close()
		})

		it("communicates with the host app when the parameters are valid", async () => {
			data = "hi"
			const response = await request(app).post("/execute-command").send({
				type: "execute-command",
				command: "hello",
				input: {},
			})
			expect(response.status).toBe(200)
			expect(response.body).toEqual("hi")
		})

		it("returns 400 if the command is not valid", async () => {
			const response = await request(app).post("/execute-command").send({
				type: "execute-command",
				input: {},
			})
			expect(response.status).toBe(400)
			expect(response.body).toEqual({
				type: "error",
				error: "Missing parameter 'command' in request body",
				data: undefined,
			})
		})

		it("returns 400 if the input is not valid", async () => {
			const response = await request(app).post("/execute-command").send({
				type: "execute-command",
				command: "hello",
				input: undefined,
			})
			expect(response.status).toBe(400)
			expect(response.body).toEqual({
				type: "error",
				error: "Missing parameter 'input' in request body",
				data: undefined,
			})
		})

		it("returns 500 if the command fails", async () => {
			error = "command failed"
			const response = await request(app).post("/execute-command").send({
				type: "execute-command",
				command: "hello",
				input: {},
			})
			expect(response.status).toBe(500)
			expect(response.body).toEqual({ type: "error", error: "command failed", data: undefined })
		})

		it("disconnects the host app if a new connection is made", async () => {
			let signalOriginalWSDidClose: (value: unknown) => void
			const originalWSDidClose = new Promise((resolve) => {
				signalOriginalWSDidClose = resolve
			})
			ws.on("close", () => {
				expect(true).toBe(true)
				signalOriginalWSDidClose(true)
			})
			const newWs = await wsRequest(server).ws("")
			await originalWSDidClose
			newWs.close()
		})
	})

	it("returns the response for the correct request", async () => {
		let signalFirstCommandReceived: (value: unknown) => void
		let firstCommandId: string | undefined
		const firstCommandReceived = new Promise((resolve) => {
			signalFirstCommandReceived = resolve
		})

		let signalSecondCommandReceived: (value: unknown) => void
		let secondCommandId: string | undefined
		const secondCommandReceived = new Promise((resolve) => {
			signalSecondCommandReceived = resolve
		})

		let commandIdx = 0
		const ws = await wsRequest(server).ws("")
		ws.on("message", (messageBuffer: Buffer) => {
			const message = JSON.parse(messageBuffer.toString("utf-8")) as ExecuteCommandRequest & { id: string }

			if (commandIdx === 0) {
				firstCommandId = message.id
				signalFirstCommandReceived(message)
			} else {
				secondCommandId = message.id
				signalSecondCommandReceived(message)
			}
			commandIdx++
		})

		const firstRequest = new Promise<Response>((resolve) =>
			request(app)
				.post("/execute-command")
				.send({
					type: "execute-command",
					command: "hello",
					input: {},
				})
				.then(resolve),
		)

		const secondRequest = new Promise<Response>((resolve) =>
			request(app)
				.post("/execute-command")
				.send({
					type: "execute-command",
					command: "hello",
					input: {},
				})
				.then(resolve),
		)

		await Promise.all([firstCommandReceived, secondCommandReceived])

		ws.send(
			JSON.stringify({
				type: "command-response",
				data: "hi 2",
				id: secondCommandId,
			}),
		)

		const secondResponse = await secondRequest
		expect(secondResponse.status).toBe(200)
		expect(secondResponse.body).toEqual("hi 2")

		ws.send(
			JSON.stringify({
				type: "command-response",
				data: "hi 1",
				id: firstCommandId,
			}),
		)

		const firstResponse = await firstRequest
		expect(firstResponse.status).toBe(200)
		expect(firstResponse.body).toEqual("hi 1")
	})

	it("Fails when sending a response for an unknown command", async () => {
		const ws = await wsRequest(server).ws("")

		let signalErrorReceived: (value: unknown) => void
		const errorReceived = new Promise((resolve) => {
			signalErrorReceived = resolve
		})

		ws.on("message", (messageBuffer: Buffer) => {
			const message = JSON.parse(messageBuffer.toString("utf-8")) as {
				type: string
				error: string
			}

			signalErrorReceived(message)
			expect(message.type).toBe("error")
			expect(message.error).toBe("No pending command for id 'unknown'")
		})
		ws.send(
			JSON.stringify({
				type: "command-response",
				data: "hi 2",
				id: "unknown",
			}),
		)
		await errorReceived
	})
})
