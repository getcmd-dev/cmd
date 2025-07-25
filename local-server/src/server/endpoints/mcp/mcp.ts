import { Request, Response, Router } from "express"
import { logInfo } from "../../../logger"
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"

import { z } from "zod"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js"
import { v4 as uuidv4 } from "uuid"

export const registerMCPServerEndpoints = (router: Router) => {
	// This function is used to register the MCP server for permissions

	// Map to store transports by session ID
	const transports: { [sessionId: string]: StreamableHTTPServerTransport } = {}

	const server = new McpServer({
		name: "Test permission prompt MCP Server",
		version: "0.0.1",
	})

	server.tool(
		"approval_prompt",
		'Simulate a permission check - approve if the input contains "allow", otherwise deny',
		{
			tool_name: z.string().describe("The name of the tool requesting permission"),
			input: z.object({}).passthrough().describe("The input for the tool"),
			tool_use_id: z.string().optional().describe("The unique tool use request ID"),
		},
		async ({ tool_name, input }) => {
			logInfo(
				`Approving permission request from tool \`${tool_name}\` with input: ${JSON.stringify(input, null, 2)}`,
			)
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
		},
	)

	// Handle POST requests for client-to-server communication
	router.post("/mcp", async (req, res) => {
		logInfo(`Received MCP request: ${JSON.stringify(req.body, null, 2)}`)
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
					// Store the transport by session ID
					transports[sessionId] = transport
				},
				// DNS rebinding protection is disabled by default for backwards compatibility. If you are running this server
				// locally, make sure to set:
				// enableDnsRebindingProtection: true,
				// allowedHosts: ['127.0.0.1'],
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
	router.get("/mcp", handleSessionRequest)

	// Handle DELETE requests for session termination
	router.delete("/mcp", handleSessionRequest)
}
