export interface SearchFilesRequestInput {
	projectRoot: string
	directoryPath: string
	regex: string
	filePattern?: string
}
