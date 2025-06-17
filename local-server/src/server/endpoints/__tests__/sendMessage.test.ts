import { describe, expect, it } from "@jest/globals"
import { mapResponseError } from "../sendMessage"

describe("mapResponseError", () => {
	const mockIdx = () => 42

	describe("openAI error", () => {
		it("should handle model_not_found", () => {
			const result = mapResponseError(
				{
					responseBody: JSON.stringify({
						message:
							"The model `gpt-4-0314` has been deprecated, learn more here: https://platform.openai.com/docs/deprecations",
						type: "invalid_request_error",
						param: null,
						code: "model_not_found",
					}),
				},
				mockIdx,
			)

			expect(result).toEqual({
				type: "error",
				message:
					"The model `gpt-4-0314` has been deprecated, learn more here: https://platform.openai.com/docs/deprecations",
				statusCode: 404,
				idx: 42,
			})
		})
		it("should handle invalid_request_error", () => {
			const result = mapResponseError(
				{
					responseBody: JSON.stringify({
						message:
							"Invalid schema for function 'list_files': In context=('properties', 'recursive'), schema must have a 'type' key.",
						type: "invalid_request_error",
						param: null,
						code: null,
					}),
				},
				mockIdx,
			)

			expect(result).toEqual({
				type: "error",
				message:
					"Invalid schema for function 'list_files': In context=('properties', 'recursive'), schema must have a 'type' key.",
				statusCode: 500,
				idx: 42,
			})
		})
	})
})
