import { ResponseError } from "@/server/schemas/sendMessageSchema"

/**
 * Maps an unknown error to a ResponseError. Deal with different error formats from supported providers.
 * @param err - The error to map.
 * @param idx - A function that returns the current index of the chunk.
 * @returns A ResponseError.
 */

const parseErrorMessage = (error: UnknownError): string | undefined => {
	if (!error) {
		return undefined
	} else if (typeof error === "string") {
		return error
	} else if (typeof error === "object" && error !== null) {
		const responseBody = error.responseBody
		if (typeof responseBody === "string") {
			try {
				const info = JSON.parse(responseBody) as ResponseBody

				try {
					// Open Router
					// @ts-expect-error - Ignoring typesafety here to simplify parsing
					const err = JSON.parse(info.error.metadata.raw).error as UnknownError
					return parseErrorMessage(err)
				} catch {}

				return info.message || info.error?.message
			} catch {}
			return responseBody
		} else {
			return error.message
		}
	} else {
		return undefined
	}
}

const parseErrorStatusCode = (error: UnknownError): number | undefined => {
	if (!error || typeof error !== "object") {
		return undefined
	} else {
		const responseBody = error.responseBody
		if (typeof responseBody === "string") {
			try {
				const info = JSON.parse(responseBody) as ResponseBody
				return mapErrorCode(info.statusCode || info.code || info.error?.statusCode || info.error?.code)
			} catch {}
		}
		return error.statusCode
	}
}

export const mapResponseError = (err: unknown, idx: () => number): ResponseError => {
	const error = err as UnknownError
	return {
		type: "error",
		message: parseErrorMessage(error) || "Error sending message",
		statusCode: parseErrorStatusCode(error) || 400,
		idx: idx(),
	}
}

type UnknownError =
	| undefined
	| string
	| {
			responseBody: string | unknown | undefined
			message: string | undefined
			statusCode: number | undefined
	  }

type ResponseBody = {
	error?: {
		message?: string
		statusCode?: number | string
		code?: number | string
	}
	message?: string
	statusCode?: number | string
	code?: number | string
}

/**
 * Maps an error code to a HTTP status code.
 * @param code - The error code to map. Format might differ between providers.
 * @returns The mapped HTTP status code.
 */
const mapErrorCode = (code: string | number | undefined): number => {
	if (typeof code === "number") {
		return code
	} else if (typeof code === "string") {
		if (code.includes("not_found")) {
			return 404
		}
	}
	return 400 // Default to 400 if code is undefined
}
