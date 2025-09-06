import { ModelProvider, ModelProviderInput, ModelProviderOutput } from "./provider"
import { APIProviderName } from "@/server/schemas/sendMessageSchema"
import { createOpenRouter, OpenRouterProviderOptions } from "@openrouter/ai-sdk-provider"
import { addCacheControlToMessages } from "./anthropic"

export class OpenRouterModelProvider implements ModelProvider {
	name: APIProviderName = "openrouter"
	build(params: ModelProviderInput): ModelProviderOutput {
		const { modelName, apiKey, baseUrl, reasoningBudget } = params
		const provider = createOpenRouter({
			apiKey: apiKey,
			baseURL: process.env["OPEN_ROUTER_LOCAL_SERVER_PROXY"] ?? baseUrl,
			fetch: modelName.startsWith("anthropic/") ? fetchAnthropicResponse : defaultFetch,
		})

		const providerOptions: OpenRouterProviderOptions = {}
		if (reasoningBudget) {
			providerOptions.reasoning = { max_tokens: reasoningBudget }
		}
		return {
			model: provider(modelName, {
				usage: {
					include: true,
				},
				reasoning: providerOptions.reasoning,
			}),
			addProviderOptionsToMessages: modelName.startsWith("anthropic/")
				? (messages) => addCacheControlToMessages(messages, this.name)
				: undefined,
		}
	}
}

const defaultFetch: typeof fetch = (input, init) => {
	if (!init?.body) return fetch(input, init)

	const body = JSON.parse(init.body as string)

	body.stream_options = {
		include_usage: true,
	}
	body.transforms = ["middle-out"]
	body.usage = { include: true }

	init.body = JSON.stringify(body)

	return fetch(input, init)
}

// See https://github.com/OpenRouterTeam/ai-sdk-provider/issues/35#issuecomment-2904161662
const fetchAnthropicResponse: typeof fetch = (input, init) => {
	if (!init?.body) return fetch(input, init)

	const body = JSON.parse(init.body as string)

	body.stream_options = {
		include_usage: true,
	}
	body.transforms = ["middle-out"]

	// Uncomment this to trigger an errror
	// if (body?.messages) {
	// 	for (const message of body.messages) {
	// 		if (typeof message.content === "string") {
	// 			message.content = [
	// 				{
	// 					type: "text",
	// 					text: message.content,
	// 					cache_control: { type: "ephemeral" },
	// 				},
	// 			]
	// 		} else if (Array.isArray(message.content)) {
	// 			for (const item of message.content) {
	// 				if (item && typeof item === "object") {
	// 					item.cache_control = { type: "ephemeral" }
	// 				}
	// 			}
	// 		}
	// 	}
	// }

	if (body?.messages) {
		for (const message of body.messages) {
			if (message.cache_control !== undefined) {
				if (typeof message.content === "string") {
					message.content = [
						{
							type: "text",
							text: message.content,
							cache_control: { type: "ephemeral" },
						},
					]
					delete message.cache_control
				}
			}
		}
	}
	if (body?.tools && body?.tools.length > 0) {
		const lastIdx = body.tools.length - 1
		body.tools[lastIdx] = {
			...body.tools[lastIdx],
			cache_control: { type: "ephemeral" },
		}
	}
	init.body = JSON.stringify(body)

	return fetch(input, init)
}
