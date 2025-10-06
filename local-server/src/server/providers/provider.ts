import { ModelMessage, JSONValue, LanguageModel } from "ai"
import { APIProviderName } from "../schemas/sendMessageSchema"
import { ToolModelWithName } from "../endpoints/sendMessage/sendMessage"

/**
 * Output from building an AI provider configuration.
 */
export type AIProviderOutput = {
	/** The language model instance to use for inference */
	model?: LanguageModel
	/** Provider-specific options organized by category */
	generalProviderOptions?: Record<string, Record<string, JSONValue>>
	/** Function to add provider-specific data to messages before sending them */
	addProviderOptionsToMessages?: (messages: Array<ModelMessage>) => Array<ModelMessage>
	/** Function to add provider-specific data to tools before sending them */
	addProviderOptionsToTools?: (tools: Array<ToolModelWithName> | undefined) => Array<ToolModelWithName> | undefined
}

/**
 * Input parameters for building an AI provider.
 */
export type AIProviderInput = {
	/** Provider configuration including credentials and endpoints */
	provider: ProviderConfig
	/** The name/identifier of the model that will be used */
	modelName: string
	/** Optional budget for reasoning tokens (for models that support extended thinking) */
	reasoningBudget?: number
}

/**
 * Configuration for connecting to an AI provider.
 */
export type ProviderConfig = {
	/** Custom base URL for the provider's API (optional) */
	baseUrl?: string
	/** API key for authentication */
	apiKey?: string
}

/**
 * Complete information about a model across all providers.
 * This is the reference data fetched from OpenRouter that includes
 * metadata about the model regardless of which provider serves it.
 */
export type ProviderModelFullInfo = {
	/** A unique id to identify this model. It is not specific to one AI provider. */
	id: string
	/** Canonical identifier slug for the model */
	canonical_slug: string
	/** A user friendly name for the model */
	name: string
	/** Description of the model's capabilities */
	description: string
	/** Maximum context length in tokens */
	context_length: number
	/** Model architecture information */
	architecture: {
		/** Types of input the model accepts (text, image, audio, etc.) */
		input_modalities: ModelModality[]
		/** Types of output the model produces */
		output_modalities: ModelModality[]
	}
	/** Information about the top/recommended provider for this model */
	top_provider: {
		/** Context length available from the top provider */
		context_length: number
		/** Maximum completion tokens allowed */
		max_completion_tokens?: number
	}
	/** Pricing information (values are strings to preserve precision) */
	pricing: {
		/** Cost per prompt token */
		prompt: string
		/** Cost per completion token */
		completion: string
		/** Cost per image */
		image: string
		/** Cost per request */
		request: string
		/** Cost for web search feature */
		web_search: string
		/** Cost for internal reasoning tokens */
		internal_reasoning: string
		/** Cost for reading from input cache */
		input_cache_read?: string
		/** Cost for writing to input cache */
		input_cache_write?: string
	}
	/** The list of AI providers that serve this model */
	providers: {
		/** Provider identifier slug */
		slug: string
		/** Human-readable provider name */
		displayName: string
		/** API base URL for this provider */
		baseUrl: string
		/** URL to the provider's icon */
		iconUrl?: string
		/** Various ways the model is known to be referred to by this provider */
		known_appelations: string[]
	}[]
	/** Model creation timestamp (Unix timestamp in seconds) */
	created: number
	/** How this model ranks in programming tasks (from OpenRouter, only available for top models) */
	rankForProgramming: number
	/** Whether the model supports extended reasoning/thinking */
	supportsReasoning: boolean
}

/**
 * Types of data modalities that models can accept or produce.
 */
export type ModelModality = "text" | "image" | "file" | "audio"

/**
 * Information about a model from one specific AI provider.
 * This is provider-specific data that may differ from other providers serving the same model.
 */
export type ProviderModel = {
	/** How this model is identified by the provider (provider-specific ID) */
	providerId: string
	/** How this model is identified across all providers (canonical ID) */
	globalId: string
	/** Display name of the model */
	name: string
	/** Description of the model's capabilities */
	description: string
	/** Maximum context length in tokens */
	context_length: number
	/** Maximum completion tokens allowed */
	max_completion_tokens?: number
	/** Model architecture information */
	architecture: {
		/** Types of input the model accepts */
		input_modalities: ModelModality[]
		/** Types of output the model produces */
		output_modalities: ModelModality[]
	}
	/** Pricing information (values are strings to preserve precision) */
	pricing: {
		/** Cost per prompt token */
		prompt: string
		/** Cost per completion token */
		completion: string
		/** Cost per image */
		image?: string
		/** Cost per request */
		request?: string
		/** Cost for web search feature */
		web_search?: string
		/** Cost for internal reasoning tokens */
		internal_reasoning?: string
		/** Cost for reading from input cache */
		input_cache_read?: string
		/** Cost for writing to input cache */
		input_cache_write?: string
	}
	/** The creation unix timestamp, in seconds */
	created: number
	/** Ranking for programming tasks */
	rankForProgramming: number
	/** Whether the model supports extended reasoning/thinking */
	supportsReasoning: boolean
}

/**
 * Interface for AI provider implementations.
 * Each provider (OpenAI, Anthropic, etc.) implements this interface
 * to provide a consistent way to interact with different AI services.
 */
export interface AIProvider {
	/**
	 * Builds a configured model instance ready for inference.
	 * @param params - Configuration including provider settings, model name, and reasoning budget
	 * @returns Model instance and optional provider-specific configuration
	 */
	build: (params: AIProviderInput) => AIProviderOutput

	/** The name of the API provider (e.g., "openai", "anthropic") */
	name: APIProviderName

	/**
	 * Lists all models available from this provider.
	 * @param config - Provider configuration (API key, base URL, etc.)
	 * @param referenceModels - Reference model data from OpenRouter for enrichment
	 * @returns Array of models with their metadata
	 */
	listModels: (config: ProviderConfig, referenceModels: ProviderModelFullInfo[]) => Promise<ProviderModel[]>
}
