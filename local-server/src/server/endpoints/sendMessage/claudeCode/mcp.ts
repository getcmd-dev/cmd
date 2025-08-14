import { Request, Response, Router } from "express"
import { McpServer, ToolCallback } from "@modelcontextprotocol/sdk/server/mcp.js"

import { z } from "zod"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js"
import { v4 as uuidv4 } from "uuid"

export const registerMCPServerEndpoints = (
	router: Router,
	path: string,
	handleApproval: (toolName: string, input: unknown) => Promise<{ isAllowed: boolean; rejectionMessage?: string }>,
) => {
	// This function is used to register the MCP server for permissions

	// Map to store transports by session ID
	const transports: { [sessionId: string]: StreamableHTTPServerTransport } = {}
	const defaultSessionId = "default"

	transports[defaultSessionId] = new StreamableHTTPServerTransport({
		sessionIdGenerator: () => uuidv4(),
		onsessioninitialized: (sessionId) => {
			// Store the transport by session ID
			transports[sessionId] = transports[defaultSessionId]
		},
	})

	const server = new McpServer({
		name: "Test permission prompt MCP LocalServer",
		version: "0.0.1",
	})
	const schema = {
		tool_name: z.string().describe("The name of the tool requesting permission"),
		input: z.object({}).passthrough().describe("The input for the tool"),
		tool_use_id: z.string().optional().describe("The unique tool use request ID"),
	}
	// eslint-disable-next-line @typescript-eslint/ban-ts-comment
	// @ts-ignore: Type instantiation is excessively deep and possibly infinite.
	const cb: ToolCallback<typeof schema> = async (args) => {
		const { tool_name, input } = args
		const { isAllowed, rejectionMessage } = await handleApproval(tool_name, input)
		if (isAllowed) {
			return {
				content: [
					{
						type: "text",
						text: JSON.stringify({
							behavior: "allow",
							updatedInput: input,
						}),
					},
				],
			}
		} else {
			return {
				content: [
					{
						type: "text",
						text: JSON.stringify({
							behavior: "deny",
							message: rejectionMessage,
						}),
					},
				],
			}
		}
	}
	server.tool(
		"tool_approval",
		'Simulate a permission check - approve if the input contains "allow", otherwise deny',
		schema,
		cb,
	)

	// Handle POST requests for client-to-server communication
	router.post(path, async (req, res) => {
		// Check for existing session ID
		const sessionId = req.headers["mcp-session-id"] as string | undefined
		let transport: StreamableHTTPServerTransport
		if (sessionId && transports[sessionId]) {
			// Reuse existing transport
			transport = transports[sessionId]
		} else if (!sessionId && isInitializeRequest(req.body)) {
			// New initialization request
			transport = new StreamableHTTPServerTransport({
				sessionIdGenerator: () => uuidv4(),
				onsessioninitialized: (sessionId) => {
					transports[sessionId] = transport
				},
			})

			// Clean up transport when closed
			transport.onclose = () => {
				if (transport.sessionId) {
					delete transports[transport.sessionId]
				}
			}

			// Connect to the MCP server
			await server.connect(transport)
		} else {
			// Invalid request
			res.status(400).json({
				jsonrpc: "2.0",
				error: {
					code: -32000,
					message: "Bad Request: No valid session ID provided",
				},
				id: null,
			})
			return
		}

		// Handle the request
		await transport.handleRequest(req, res, req.body)
	})

	// Reusable handler for GET and DELETE requests
	const handleSessionRequest = async (req: Request, res: Response) => {
		const sessionId = req.headers["mcp-session-id"] as string | undefined
		if (!sessionId || !transports[sessionId]) {
			res.status(400).send("Invalid or missing session ID")
			return
		}

		const transport = transports[sessionId]
		await transport.handleRequest(req, res)
	}

	// Handle GET requests for server-to-client notifications via SSE
	router.get(path, handleSessionRequest)

	// Handle DELETE requests for session termination
	router.delete(path, handleSessionRequest)
}
