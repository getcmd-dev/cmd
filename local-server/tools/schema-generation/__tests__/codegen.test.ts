import { describe, expect, it } from "@jest/globals"
import { generateSwiftSchema } from "../jsonSchemaToSwift"
import { generateJSONSchema } from "../tsToJSONSchema"
import dedent from "dedent-js"
import path from "path"
import { fileURLToPath } from "url"
import { toSnakeCase } from "../utils"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const itMatchesSnapshot = (testName: string, tsCode: string) => {
	it(testName, () => {
		const jsonSchema = generateJSONSchema({
			content: tsCode,
		})
		const swiftSchema = generateSwiftSchema(jsonSchema, "schemaFile", "Schema")

		const normalizedTestName = toSnakeCase(testName.replace(/ /g, "_"))

		// @ts-expect-error not sure why TS is unhappy, not worth fixing...

		expect(`${dedent(tsCode)}\n`).toMatchFile(
			path.join(__dirname, "__snapshots__", normalizedTestName, "schema.ts"),
		)
		// @ts-expect-error not sure why TS is unhappy, not worth fixing...

		expect(swiftSchema).toMatchFile(path.join(__dirname, "__snapshots__", normalizedTestName, "schema.swift"))
		// @ts-expect-error not sure why TS is unhappy, not worth fixing...

		expect(JSON.stringify(jsonSchema, null, 2)).toMatchFile(
			path.join(__dirname, "__snapshots__", normalizedTestName, "schema.json"),
		)
	})
}

describe("Schema Generation", () => {
	itMatchesSnapshot(
		"one object with value types",
		`
      export interface ValueType {
        int: number;
        string: string;
        boolean: boolean;
        array: string[];
      }
    `,
	)

	itMatchesSnapshot(
		"one object with optional value types",
		`
      export interface ValueType {
        int?: number;
        string?: string;
        boolean?: boolean;
        array?: string[];
      }
    `,
	)

	itMatchesSnapshot(
		"nested optional value types",
		`
      export interface ValueType {
        array?: (string | undefined)[];
      }
    `,
	)

	itMatchesSnapshot(
		"nested type",
		`
      export interface ValueType {
        nested_value: NestedValueType;
      }
      export interface NestedValueType {
        value: string;
      }
    `,
	)

	itMatchesSnapshot(
		"type with fixed value",
		`
      export interface ValueType {
        type: "value";
        value: number;
      }
    `,
	)

	itMatchesSnapshot(
		"one of two types",
		`
      export interface NumberType {
        type: "number";
        value: number;
      }
      export interface BooleanType {
        type: "boolean";
        value: boolean;
      }
      export type ValueType = NumberType | BooleanType;
    `,
	)

	itMatchesSnapshot(
		"inline type definition",
		`
      export interface ValueType {
        nested: {
          value: string;
        };
      }
    `,
	)

	itMatchesSnapshot(
		"inline enum definition",
		`
      export interface NumberType {
        type: "number";
        value: number;
      }
      export interface BooleanType {
        type: "boolean";
        value: boolean;
      }
      export interface ValueType {
        value: BooleanType | NumberType;
      }
    `,
	)

	itMatchesSnapshot(
		"json object",
		`
      export interface Wrapper {
        properties: Record<string, unknown>;
      }
    `,
	)

	itMatchesSnapshot(
		"property with several fixed values",
		`
      export interface Message {
        role: "system" | "user" | "assistant" | "function_call";
        single_value: "single_value";
      }
    `,
	)

	itMatchesSnapshot(
		"one object with integer value types",
		`
      export interface ValueType {
        /**
         * @format integer
         */
        line: number;
        /**
         * @format integer
         */
        column?: number;
      }
    `,
	)
})
