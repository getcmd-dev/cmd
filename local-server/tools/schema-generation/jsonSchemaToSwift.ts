import Handlebars from "handlebars"
import fs from "fs"
import { fileURLToPath } from "url"
import { dirname } from "path"
import { JSONSchema7, JSONSchema7Definition, JSONSchema7Type } from "json-schema"
import { toCamelCase, toPascalCase } from "./utils"

const __filename = fileURLToPath(import.meta.url)
const dir = dirname(__filename)

/// When a type is a one of two types, the key that is required to differentiate them.
const typeKey = "type"

class ModelsGenerator {
	private models: Map<string, ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel>
	public schema: JSONSchema7

	public get topLevelDefinitions(): Array<ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel> {
		return this.definitions.filter((definition) => !definition.qualifiedTypeName.includes("."))
	}

	public originalFile: string

	private get definitions(): Array<ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel> {
		return Array.from(this.models.values())
	}

	constructor(schema: JSONSchema7, name: string) {
		this.originalFile = name
		this.schema = schema
		this.models = new Map()
		Object.entries(schema.definitions ?? {}).forEach(([qualifiedTypeName, definition]) => {
			this.models.set(qualifiedTypeName, this.createModel({ qualifiedTypeName, definition }))
		})

		// Move nested definitions under their parent type.
		this.definitions.forEach((definition) => {
			const typeNameQualifier = getQualifier(definition.qualifiedTypeName)
			if (typeNameQualifier !== "") {
				// This is not a top level definition, locate it under its parent type.
				const parentDefinition = this.getModel(typeNameQualifier)
				if (!parentDefinition) {
					throw new Error(`Parent definition ${typeNameQualifier} not found`)
				}
				if (isObjectTypeModel(parentDefinition)) {
					parentDefinition.nestedDefinitions.push(definition)
				} else {
					throw new Error(`Parent definition ${typeNameQualifier} is not an object type`)
				}
			}
		})
	}

	getModel(
		qualifiedTypeName: string,
	): ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel | undefined {
		if (!this.models.has(qualifiedTypeName)) {
			// Generate the model now.
			const definition = this.schema.definitions?.[qualifiedTypeName]
			if (!definition) {
				throw new Error(`Model ${qualifiedTypeName} not found`)
			}
			this.createModel({ qualifiedTypeName, definition })
		}
		return this.models.get(qualifiedTypeName)
	}

	public createModel({
		qualifiedTypeName,
		definition,
	}: {
		qualifiedTypeName: string
		definition: JSONSchema7Definition
	}): ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel {
		if (typeof definition === "boolean") {
			throw new Error("Definition is boolean")
		}
		let model: ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel
		if (definition.anyOf) {
			model = new OneOfDefinitionModel({
				generator: this,
				qualifiedTypeName,
				definitions: definition.anyOf,
			})
		} else if (definition.enum) {
			model = new EnumDefinitionModel({
				qualifiedTypeName,
				definition: definition,
			})
		} else {
			model = new ObjectDefinitionModel({
				generator: this,
				qualifiedTypeName,
				definition: definition,
			})
		}

		this.models.set(qualifiedTypeName, model)
		return model
	}
}

class OneOfDefinitionModel {
	type = "oneOf"
	isOneOfType = true
	typeName: string
	qualifiedTypeName: string
	cases: Array<{ name: string; type: string; typeValue: string }>
	typeKey = typeKey

	constructor({
		generator,
		qualifiedTypeName,
		definitions,
	}: {
		generator: ModelsGenerator
		qualifiedTypeName: string
		definitions: Array<JSONSchema7Definition>
	}) {
		const refDefinitions = definitions.filter((definition): definition is { $ref: string } => {
			if (typeof definition === "boolean") {
				throw new Error("Definition is boolean")
			}
			if ("$ref" in definition) {
				return true
			}
			throw new Error("not handled")
		})

		this.qualifiedTypeName = qualifiedTypeName
		this.typeName = unqualify(qualifiedTypeName)
		this.cases = refDefinitions.map((definition) => {
			const referencedTypeName = definition.$ref.replace("#/definitions/", "")
			const referencedTypes = generator.getModel(referencedTypeName)
			if (!isObjectTypeModel(referencedTypes)) {
				throw new Error(`Referenced type ${referencedTypeName} is not an object type. Not yet handled`)
			}

			const typeValue = referencedTypes.properties.find((property) => property.name === typeKey)?.fixedValue

			if (!typeValue) {
				throw new Error(`Referenced type ${referencedTypeName} does not have a ${typeKey} property`)
			}

			return {
				name: toCamelCase(referencedTypeName),
				type: referencedTypeName,
				typeValue,
			}
		})
	}
}

class ObjectDefinitionModel {
	type = "object"
	typeName: string
	qualifiedTypeName: string
	properties: Array<PropertyModel>
	isObjectType = true
	nestedDefinitions: Array<ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel>

	constructor({
		generator,
		qualifiedTypeName,
		definition,
	}: {
		generator: ModelsGenerator
		qualifiedTypeName: string
		definition: JSONSchema7
	}) {
		this.qualifiedTypeName = qualifiedTypeName
		this.typeName = unqualify(qualifiedTypeName)
		this.nestedDefinitions = []
		if (typeof definition === "boolean") {
			throw new Error("Definition is boolean")
		}
		if (definition.properties) {
			this.properties = Object.entries(definition.properties).map(
				([decodingKey, property]) =>
					new PropertyModel({
						generator: generator,
						typeNameQualifier: qualifiedTypeName,
						decodingKey,
						definition: property,
						isRequired: definition.required?.includes(decodingKey) ?? false,
					}),
			)
		} else {
			throw new Error("Definition is not an object")
		}
	}
}

class EnumDefinitionModel {
	type = "enum"
	isEnumType = true
	typeName: string
	qualifiedTypeName: string
	cases: Array<{ name: string; value: string }>

	constructor({ qualifiedTypeName, definition }: { qualifiedTypeName: string; definition: JSONSchema7 }) {
		this.qualifiedTypeName = qualifiedTypeName
		this.typeName = unqualify(qualifiedTypeName)
		if (!definition.enum) {
			throw new Error("Definition is not an enum")
		}
		this.cases = definition.enum.map((value) => {
			if (typeof value !== "string") {
				throw new Error("Enum value is not a string")
			}
			return {
				name: toCamelCase(value),
				value,
			}
		})
	}
}

class PropertyModel {
	decodingKey: string
	name: string
	typeName: string
	fixedValue?: string
	isRequired: boolean

	constructor({
		generator,
		typeNameQualifier,
		decodingKey,
		definition,
		isRequired,
	}: {
		generator: ModelsGenerator
		typeNameQualifier: string
		decodingKey: string
		definition: JSONSchema7Definition
		isRequired: boolean
	}) {
		if (typeof definition === "boolean") {
			throw new Error("Definition is boolean")
		}
		this.decodingKey = decodingKey
		this.name = toCamelCase(decodingKey)
		if (definition.const) {
			this.fixedValue = valueRepresentation(definition.const)
		}
		this.isRequired = isRequired
		if (typeof definition.type === "string") {
			this.typeName = getTypeName({
				generator,
				typeNameQualifier,
				propertyKey: this.name,
				type: definition,
				isRequired,
			})
		} else if (definition.$ref) {
			const ref = definition.$ref.replace("#/definitions/", "")
			this.typeName = `${ref}${isRequired ? "" : "?"}`
		} else if (definition.anyOf) {
			// handle when this is actually an optional type.
			const anyOfWithoutNull = definition.anyOf.filter((t) => !isNullType(t))
			if (anyOfWithoutNull.length !== definition.anyOf.length) {
				throw new Error("Type is an anyOf with null type. Not yet handled")
			}
			this.typeName = getTypeName({
				generator,
				typeNameQualifier,
				propertyKey: this.name,
				type: definition,
				isRequired,
			})
		} else if (typeof definition === "object" && Object.keys(definition).length === 0) {
			this.typeName = "JSON.Value"
		} else {
			throw new Error("Type is not a string")
		}
	}
}

// Whether the type is null or undefined.
const isNullType = (type: JSONSchema7Definition): boolean => {
	// A type is a null type if it has a `not` property with an empty object, ie `{ not: {} }`
	if (typeof type !== "object") {
		return false
	}
	if (type.not === undefined) {
		return false
	}
	return Object.keys(type.not).length === 0
}

// An untyped JSON object (eg `Record<string, unknown>` in TypeScript)
const isJSONObject = (type: JSONSchema7): boolean => {
	return type.type === "object" && type.properties === undefined
}

const unqualify = (qualifiedTypeName: string): string => {
	return qualifiedTypeName.split(".").pop() ?? qualifiedTypeName
}

const getQualifier = (qualifiedTypeName: string): string => {
	return qualifiedTypeName.split(".").slice(0, -1).join(".")
}

const isObjectTypeModel = (
	model: ObjectDefinitionModel | OneOfDefinitionModel | EnumDefinitionModel | undefined,
): model is ObjectDefinitionModel => {
	return model?.type === "object"
}

const valueRepresentation = (value: JSONSchema7Type): string => {
	if (typeof value === "string") {
		return `"${value}"`
	} else if (typeof value === "number") {
		return value.toString()
	} else if (typeof value === "boolean") {
		return value ? "true" : "false"
	}
	throw new Error(`Representing ${JSON.stringify(value)} as a string is not yet implemented`)
}

const getTypeName = ({
	generator,
	typeNameQualifier,
	propertyKey,
	type,
	isRequired,
}: {
	generator: ModelsGenerator
	typeNameQualifier: string
	propertyKey: string
	type: JSONSchema7
	isRequired: boolean
}): string => {
	if (!isRequired) {
		return `${getTypeName({ generator, typeNameQualifier, propertyKey, type, isRequired: true })}?`
	}

	if (type.type === "string") {
		if (type.enum) {
			// For example, `role: "system" | "user" | "assistant"`
			if (type.enum.length === 1) {
				return "String"
			} else {
				const typeName = toPascalCase(propertyKey)
				generator.createModel({
					qualifiedTypeName: `${typeNameQualifier}.${typeName}`,
					definition: type,
				})
				return typeName
			}
		} else {
			return "String"
		}
	} else if (type.type === "number") {
		if (type.format === "integer") {
			return "Int"
		} else {
			return "Double"
		}
	} else if (type.type === "boolean") {
		return "Bool"
	} else if (isJSONObject(type)) {
		return "JSON"
	} else if (type.type === "array") {
		if (typeof type.items === "boolean") {
			throw new Error("Items is boolean")
		} else if (Array.isArray(type.items)) {
			throw new Error("Items is an array")
		} else if (type.items === undefined) {
			throw new Error("Items is undefined")
		} else {
			return `[${getTypeName({ generator, typeNameQualifier, propertyKey, type: type.items, isRequired: true })}]` // TODO: handle non-required arrays element
		}
	} else if (type.$ref) {
		return type.$ref.replace("#/definitions/", "")
	} else if (type.type === "object") {
		// Inline type.
		const typeName = toPascalCase(propertyKey)
		generator.createModel({
			qualifiedTypeName: `${typeNameQualifier}.${typeName}`,
			definition: type,
		})
		return typeName
	} else if (type.anyOf) {
		// Handle optionals, such as `string | undefined`
		const anyOfWithoutNull = type.anyOf.filter((t) => !isNullType(t))
		const isRequired = anyOfWithoutNull.length === type.anyOf.length

		if (anyOfWithoutNull.length === 1) {
			const type = anyOfWithoutNull[0]
			if (typeof type === "boolean") {
				return `Bool${isRequired ? "" : "?"}`
			}
			return getTypeName({
				generator,
				typeNameQualifier,
				propertyKey,
				type,
				isRequired,
			})
		} else {
			// Inline enum definition.
			const typeName = toPascalCase(propertyKey)
			generator.createModel({
				qualifiedTypeName: `${typeNameQualifier}.${typeName}`,
				definition: type,
			})
			return `${typeName}${isRequired ? "" : "?"}`
		}
	} else {
		throw new Error("Type is not a string")
	}
}

export const generateSwiftSchema = (schema: JSONSchema7, name: string) => {
	const templates = fs.readdirSync(`${dir}/templates`)

	const partials = templates.reduce(
		(acc, template) => {
			const templatePath = `${dir}/templates/${template}`
			const templateName = template.split(".")[0]
			return { ...acc, [templateName]: fs.readFileSync(templatePath, "utf8") }
		},
		{} as Record<string, string>,
	)

	const mainTemplate = fs.readFileSync(`${dir}/templates/file.hbs`, "utf8")
	const template = Handlebars.compile(mainTemplate)
	Object.entries(partials).forEach(([name, partial]) => {
		Handlebars.registerPartial(name, partial)
	})

	const modelsGenerator = new ModelsGenerator(schema, name)
	return template(modelsGenerator, {
		allowProtoMethodsByDefault: true,
		allowProtoPropertiesByDefault: true,
	})
}
