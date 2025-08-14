import fs from "fs"
import { generateJSONSchemas } from "./schema-generation/tsToJSONSchema"
import { generateSwiftSchema } from "./schema-generation/jsonSchemaToSwift"

const generate = () => {
	const jsonSchemas = generateJSONSchemas({
		path: "./src/server/schemas",
	})
	for (const { name, schema: jsonSchema } of jsonSchemas) {
		const swiftSchema = generateSwiftSchema(jsonSchema, name)

		fs.writeFileSync(
			`../app/modules/serviceInterfaces/LocalServerServiceInterface/Sources/${name}.generated.swift`,
			swiftSchema,
		)
	}
}

generate()

export default generate
