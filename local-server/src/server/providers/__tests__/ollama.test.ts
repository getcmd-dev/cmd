import { describe, expect, it, beforeEach, jest } from "@jest/globals"
import { OllamaAIProvider } from "../ollama"
import { ProviderConfig, ProviderModelFullInfo } from "../provider"
import { UserFacingError } from "../../errors"

// Mock global fetch
global.fetch = jest.fn() as jest.MockedFunction<typeof fetch>

describe("OllamaAIProvider", () => {
	let provider: OllamaAIProvider
	let mockFetch: jest.MockedFunction<typeof fetch>

	beforeEach(() => {
		provider = new OllamaAIProvider()
		mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
		mockFetch.mockClear()
	})

	describe("provider metadata", () => {
		it("should have correct provider name", () => {
			expect(provider.name).toBe("ollama")
		})
	})

	describe("build", () => {
		it("should create provider with default baseURL", () => {
			const result = provider.build({
				provider: {},
				modelName: "llama2",
			})

			expect(result.model).toBeDefined()
			expect(result.generalProviderOptions).toEqual({})
		})

		it("should create provider with custom baseURL", () => {
			const result = provider.build({
				provider: {
					baseUrl: "http://custom-ollama:11434/api",
				},
				modelName: "mistral",
			})

			expect(result.model).toBeDefined()
		})

		it("should append /api to baseURL if not yet present", () => {
			const result = provider.build({
				provider: {
					baseUrl: "http://custom-ollama:11434",
				},
				modelName: "llama2",
			})

			expect(result.model).toBeDefined()
		})

		it("should respect OLLAMA_LOCAL_SERVER_PROXY in build()", () => {
			const originalEnv = process.env.OLLAMA_LOCAL_SERVER_PROXY
			process.env.OLLAMA_LOCAL_SERVER_PROXY = "http://proxy:9999"

			const result = provider.build({
				provider: {},
				modelName: "llama2",
			})

			expect(result.model).toBeDefined()

			// Restore
			if (originalEnv) {
				process.env.OLLAMA_LOCAL_SERVER_PROXY = originalEnv
			} else {
				delete process.env.OLLAMA_LOCAL_SERVER_PROXY
			}
		})
	})

	describe("listModels", () => {
		it("should respect OLLAMA_LOCAL_SERVER_PROXY environment variable", async () => {
			const originalEnv = process.env.OLLAMA_LOCAL_SERVER_PROXY
			process.env.OLLAMA_LOCAL_SERVER_PROXY = "http://proxy:9999"

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => ({ models: [] }),
			} as Response)

			const config: ProviderConfig = {}
			await provider.listModels(config, [])

			expect(mockFetch).toHaveBeenCalledWith("http://proxy:9999/api/tags")

			// Restore original env
			if (originalEnv) {
				process.env.OLLAMA_LOCAL_SERVER_PROXY = originalEnv
			} else {
				delete process.env.OLLAMA_LOCAL_SERVER_PROXY
			}
		})

		it("should use custom baseURL when provided", async () => {
			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => ({ models: [] }),
			} as Response)

			const config: ProviderConfig = {
				baseUrl: "http://custom-host:8080",
			}

			await provider.listModels(config, [])

			expect(mockFetch).toHaveBeenCalledWith("http://custom-host:8080/api/tags")
		})

		it("should throw UserFacingError when API request fails", async () => {
			mockFetch.mockResolvedValueOnce({
				ok: false,
				status: 500,
				statusText: "Internal Server Error",
			} as Response)

			const config: ProviderConfig = {}

			await expect(provider.listModels(config, [])).rejects.toThrow(UserFacingError)
		})

		it("should handle Ollama server not running", async () => {
			mockFetch.mockRejectedValueOnce(new Error("fetch failed"))

			const config: ProviderConfig = {}

			await expect(provider.listModels(config, [])).rejects.toThrow()
		})

		it("should handle empty models list", async () => {
			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => ({ models: [] }),
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models).toEqual([])
		})

		it("should handle failed detail requests", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "test-model:latest",
						model: "test-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "1B",
							quantization_level: "Q4",
						},
					},
				],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			// Mock failed detail request
			mockFetch.mockResolvedValueOnce({
				ok: false,
				status: 404,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(0)
		})

		it("should fetch and parse model from Ollama API", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "llama2:latest",
						model: "llama2",
						modified_at: "2024-01-01T00:00:00Z",
						size: 3825819519,
						digest: "abc123",
						details: {
							format: "gguf",
							family: "llama",
							parameter_size: "7B",
							quantization_level: "Q4_0",
						},
					},
					{
						name: "codellama:13b",
						model: "codellama",
						modified_at: "2024-01-02T00:00:00Z",
						size: 7365960935,
						digest: "def456",
						details: {
							format: "gguf",
							family: "llama",
							parameter_size: "13B",
							quantization_level: "Q4_0",
						},
					},
				],
			}

			const mockModelDetails = {
				model_info: {
					"general.base_model.0.name": "Llama 2",
					"general.architecture": "llama",
					"llama.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "llama",
					parameter_size: "7B",
					quantization_level: "Q4_0",
				},
				capabilites: ["completion", "tools"],
			}

			// Mock /api/tags call
			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			// Mock /api/show calls for each model
			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			// Should call /api/tags once and /api/show twice (once per model)
			expect(mockFetch).toHaveBeenCalledTimes(3)
			expect(models.length).toBeGreaterThan(0)
		})

		it("should extract context length from model details", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "qwen2.5-coder:1.5b",
						model: "qwen2.5-coder",
						modified_at: "2024-01-01T00:00:00Z",
						size: 986062089,
						digest: "test123",
						details: {
							format: "gguf",
							family: "qwen2",
							parameter_size: "1.5B",
							quantization_level: "Q4_K_M",
						},
					},
				],
			}

			const mockModelDetails = {
				model_info: {
					"general.base_model.0.name": "Qwen2.5 Coder 1.5B",
					"general.base_model.0.organization": "Qwen",
					"general.architecture": "qwen2",
					"qwen2.context_length": 32768,
					"general.size_label": "1.5B",
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "qwen2",
					parameter_size: "1.5B",
					quantization_level: "Q4_K_M",
				},
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].context_length).toBe(32768)
		})

		it("should derive input modalities from capabilities", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "vision-model:latest",
						model: "vision-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsWithVision = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 8192,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "vision", "tools"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsWithVision,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].architecture.input_modalities).toContain("text")
			expect(models[0].architecture.input_modalities).toContain("image")
		})

		it("should default to text-only modality when no capabilities", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "text-only-model:latest",
						model: "text-only-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsNoCapabilities = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				// No capabilities field
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsNoCapabilities,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].architecture.input_modalities).toEqual(["text"])
		})

		it("should derive supportsChat from completion capability", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "chat-model:latest",
						model: "chat-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsWithChat = {
				model_info: {
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "tools"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsWithChat,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models[0].supportsChat).toBe(true)
		})

		it("should set supportsChat to false without completion capability", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "no-chat-model:latest",
						model: "no-chat-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsNoChat = {
				model_info: {
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["vision"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsNoChat,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models[0].supportsChat).toBe(false)
		})

		it("should derive supportsTools from capabilities", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "tools-model:latest",
						model: "tools-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsWithTools = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "tools"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsWithTools,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsTools).toBe(true)
		})

		it("should set supportsTools to false when no tools capability", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "no-tools-model:latest",
						model: "no-tools-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsNoTools = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "vision"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsNoTools,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsTools).toBe(false)
		})

		it("should derive supportsReasoning from capabilities", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "reasoning-model:latest",
						model: "reasoning-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsWithReasoning = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "thinking", "tools"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsWithReasoning,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsReasoning).toBe(true)
		})

		it("should set supportsReasoning to false when no thinking capability", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "no-reasoning-model:latest",
						model: "no-reasoning-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsNoReasoning = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsNoReasoning,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsReasoning).toBe(false)
		})

		it("should derive supportsCompletion from capabilities", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "completion-model:latest",
						model: "completion-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsWithCompletion = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "tools", "insert"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsWithCompletion,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsCompletion).toBe(true)
		})

		it("should set supportsCompletion to false when no completion capability", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "no-completion-model:latest",
						model: "no-completion-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsNoCompletion = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["vision", "tools"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsNoCompletion,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].supportsCompletion).toBe(false)
		})

		it("should handle all capabilities together", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "full-featured-model:latest",
						model: "full-featured-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetailsFullFeatured = {
				model_info: {
					"general.architecture": "test",
					"test.context_length": 8192,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
				capabilities: ["completion", "vision", "thinking", "tools", "insert"],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetailsFullFeatured,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(1)
			expect(models[0].architecture.input_modalities).toContain("text")
			expect(models[0].architecture.input_modalities).toContain("image")
			expect(models[0].supportsChat).toBe(true)
			expect(models[0].supportsTools).toBe(true)
			expect(models[0].supportsReasoning).toBe(true)
			expect(models[0].supportsCompletion).toBe(true)
		})

		it("should set high rankForProgramming for code models", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "codellama:7b",
						model: "codellama",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "llama",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetails = {
				model_info: {
					"general.architecture": "llama",
					"llama.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "llama",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models[0].rankForProgramming).toBe(100)
		})

		it("should set high rankForProgramming for dev-prefixed models", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "devllama:latest",
						model: "devllama",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "llama",
							parameter_size: "7B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetails = {
				model_info: {
					"general.architecture": "llama",
					"llama.context_length": 4096,
				},
				details: {
					parent_model: "",
					format: "gguf",
					family: "llama",
					parameter_size: "7B",
					quantization_level: "Q4",
				},
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models[0].rankForProgramming).toBe(100)
		})

		it("should use default context length when model_info is missing", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "minimal:latest",
						model: "minimal",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "1B",
							quantization_level: "Q4",
						},
					},
				],
			}

			const mockModelDetails = {
				// No model_info
				details: {
					parent_model: "",
					format: "gguf",
					family: "test",
					parameter_size: "1B",
					quantization_level: "Q4",
				},
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockModelDetails,
			} as Response)

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models[0].context_length).toBe(4096)
		})

		it("should return null on network error during detail fetch", async () => {
			const mockOllamaResponse = {
				models: [
					{
						name: "test-model:latest",
						model: "test-model",
						modified_at: "2024-01-01T00:00:00Z",
						size: 1000000,
						digest: "test123",
						details: {
							format: "gguf",
							family: "test",
							parameter_size: "1B",
							quantization_level: "Q4",
						},
					},
				],
			}

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockOllamaResponse,
			} as Response)

			// Mock network error
			mockFetch.mockRejectedValueOnce(new Error("Network error"))

			const config: ProviderConfig = {}
			const models = await provider.listModels(config, [])

			expect(models.length).toBe(0)
		})
	})
})
