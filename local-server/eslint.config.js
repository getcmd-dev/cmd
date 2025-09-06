// @ts-check

import eslint from "@eslint/js"
import tseslint from "typescript-eslint"
import eslintPluginPrettierRecommended from "eslint-plugin-prettier/recommended"

export default tseslint.config(
	{
		ignores: ["node_modules/", "dist/", "**/__snapshots__/"],
	},
	{
		files: ["**/*.ts", "**/*.tsx", "**/*.js"],
		languageOptions: {
			globals: {
				process: "readonly",
				console: "readonly",
				global: "readonly",
				Buffer: "readonly",
				__dirname: "readonly",
				__filename: "readonly",
			},
		},
		extends: [eslint.configs.recommended, eslintPluginPrettierRecommended],
		rules: {
			"prettier/prettier": "error",
			// Turn off rules that might conflict with Prettier
			indent: "off",
			"linebreak-style": "off",
			quotes: "off",
			semi: "off",
			"no-empty": "off",
			// Relax unused vars for JS files
			"no-unused-vars": "warn",
		},
	},
	{
		files: ["**/*.ts", "**/*.tsx"],
		languageOptions: {
			parser: tseslint.parser,
			parserOptions: {
				project: "./tsconfig.json",
			},
		},
		extends: tseslint.configs.recommended,
		rules: {
			indent: "off",
			"@typescript-eslint/no-namespace": "off",
			"@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
			// Enforce awaiting all promises
			"@typescript-eslint/no-floating-promises": "error",
		},
	},
)
