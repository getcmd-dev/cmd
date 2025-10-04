import tsj from "ts-json-schema-generator"
import ts from "typescript"
import fs from "fs"
import { dirname } from "path"

export const generateJSONSchemas = (params: { path: string }): { name: string; schema: tsj.Schema }[] => {
	const files = fs.readdirSync(params.path)
	return files.map((file) => {
		const filePath = `${params.path}/${file}`
		const schema = generateJSONSchema({ path: filePath })
		const name = file.split(".")[0]
		return { name, schema }
	})
}

/** Return the name of types defined in a given file */
const getTypeNamesDefinedInFile = (filePath: string): string[] => {
	const sourceCode = fs.readFileSync(filePath, "utf8")
	const sourceFile = ts.createSourceFile(filePath, sourceCode, ts.ScriptTarget.Latest, true)

	const typeNames: string[] = []

	// Visit each node in the AST
	function visit(node: ts.Node) {
		if (ts.isTypeAliasDeclaration(node)) {
			typeNames.push(node.name.text)
		}
		if (ts.isInterfaceDeclaration(node)) {
			typeNames.push(node.name.text)
		}
		if (ts.isClassDeclaration(node) && node.name) {
			typeNames.push(node.name.text)
		}
		if (ts.isEnumDeclaration(node)) {
			typeNames.push(node.name.text)
		}
		ts.forEachChild(node, visit)
	}

	// Start visiting from the source file
	visit(sourceFile)

	return typeNames
}

export const generateJSONSchema = (params: { path: string } | { content: string }): tsj.Schema => {
	let config: tsj.Config
	if ("path" in params) {
		config = {
			path: params.path,
			tsconfig: "./tsconfig.json",
			type: "*",
		}
	} else {
		const path = "./tmp/schema.ts"
		fs.mkdirSync(dirname(path), { recursive: true })
		fs.writeFileSync(path, params.content)
		config = {
			path,
			tsconfig: "./tsconfig.json",
			type: "*",
		}
	}

	const schema = tsj.createGenerator(config).createSchema(config.type)
	// Only generate types defined in the current file (not imported types)
	const definitions = schema.definitions
	if (config.path && definitions) {
		const typeNames = new Set(getTypeNamesDefinedInFile(config.path))
		Object.keys(definitions).forEach((key) => {
			if (!typeNames.has(key)) {
				delete definitions[key]
			}
		})
	}

	if ("content" in params && config.path) {
		fs.unlinkSync(config.path)
	}
	return schema
}
