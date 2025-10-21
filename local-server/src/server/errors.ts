export class UserFacingError extends Error {
	type = "user-facing-error"
	statusCode?: number
	userFacingMessage: string
	underlyingError?: Error

	constructor({
		message,
		statusCode,
		underlyingError,
	}: {
		message: string
		statusCode?: number
		underlyingError?: Error
	}) {
		super(message)
		this.statusCode = statusCode
		this.userFacingMessage = message
		this.underlyingError = underlyingError
		this.stack = underlyingError?.stack
		// This is needed to ensure proper prototype chain for instanceof checks
		Object.setPrototypeOf(this, UserFacingError.prototype)
	}
}

export const isUserFacingError = (error: unknown): error is UserFacingError => {
	return typeof error === "object" && error !== null && "type" in error && error.type === "user-facing-error"
}

export const addUserFacingError = (error: unknown, message: string, statusCode?: number) => {
	if (isUserFacingError(error)) {
		return error
	}
	return new UserFacingError({
		message: message,
		statusCode: statusCode,
		underlyingError: error as Error | undefined,
	})
}
