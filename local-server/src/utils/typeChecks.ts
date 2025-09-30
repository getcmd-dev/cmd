export const notEmpty = <TValue>(value: TValue | null | undefined): value is TValue => {
	return value !== null && value !== undefined
}

export const notUndefined = <TValue>(value: TValue | undefined): value is TValue => {
	return value !== undefined
}
