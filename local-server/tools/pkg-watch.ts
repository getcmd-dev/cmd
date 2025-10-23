import chokidar from "chokidar"
import { execSync, spawn } from "child_process"
import { computeAndSaveHash } from "../build.js"
import generateSwiftSchema from "./generateSwiftSchema.js"
import { existsSync } from "fs"

const isWatcherDisabled = (): boolean => {
	// The watcher might be temporarily disabled to avoid interfering with other processes.
	return existsSync("../.build/disable-watcher")
}

chokidar.watch("./dist/main.bundle.cjs", { ignoreInitial: true }).on("all", async (evt, name) => {
	if (isWatcherDisabled()) {
		return
	}
	console.log("changed.", name)

	await computeAndSaveHash()

	const child = spawn("yarn", ["copy-to-app"], {
		stdio: "inherit",
		shell: true,
	})

	child.on("error", (error) => {
		console.error(`Error executing command: ${error}`)
	})
})

chokidar.watch("./src/server/schemas", { ignoreInitial: true }).on("all", (evt, name) => {
	if (isWatcherDisabled()) {
		return
	}
	console.log("changed.", name)
	try {
		generateSwiftSchema()
	} catch (error) {
		console.error(`Error generating Swift schema: ${error as Error}`)
	}
})

chokidar
	.watch("../app/modules/**/*.swift", {
		ignoreInitial: true,
		ignored: [
			"**/.build/**",
			"**/Package.swift",
			"**/Module.swift",
			"**/*.generated.*.swift",
			(filePath) => {
				try {
					execSync(`git check-ignore ${filePath}`)
					return true
				} catch {
					// The command fails when the file is not ignored.
					return false
				}
			},
		],
	})
	.on("all", (evt, filePath) => {
		try {
			if (isWatcherDisabled()) {
				return
			}
			console.log("changed.", filePath)

			const appPath = import.meta.resolve("../../app").replace("file://", "").replace("index.json", "")

			// Look for Package.swift files in the modules directory that are not checked in. Their presence indicates that they need to be updated.
			const ignoredSwiftPackage = () => {
				try {
					return execSync(
						`find ${appPath}/modules -not -path './.git/*' -name Package.swift 2>/dev/null | git check-ignore --stdin`,
					)
				} catch {
					return ""
				}
			}
			const generateAllPackages = `${ignoredSwiftPackage()}`.includes("Package.swift")

			execSync(`${appPath}/../cmd.sh sync:dependencies ${generateAllPackages ? "--all" : ""}`)
		} catch (error) {
			console.error(`Error watching file changes: ${error as Error}`)
		}
	})
