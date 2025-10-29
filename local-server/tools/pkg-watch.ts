import chokidar from "chokidar"
import { execSync, spawn } from "child_process"
import { computeAndSaveHash } from "../build.js"
import generateSwiftSchema from "./generateSwiftSchema.js"
import { existsSync } from "fs"
import path from "path"
import globRegex from "glob-regex"

const isWatcherDisabled = (): boolean => {
	// The watcher might be temporarily disabled to avoid interfering with other processes.
	return existsSync("../.build/disable-watcher")
}

const repoRootPath = new URL("../../", import.meta.url).pathname

chokidar
	.watch(path.join(repoRootPath, "local-server/dist/main.bundle.cjs"), { ignoreInitial: true })
	.on("all", async (evt, name) => {
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
	.on("error", (error) => {
		console.error("pkg-watch: watcher error:", error)
	})

chokidar
	.watch(path.join(repoRootPath, "local-server/src/server/schemas"), { ignoreInitial: true })
	.on("all", (evt, name) => {
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
	.on("error", (error) => {
		console.error("pkg-watch: watcher error:", error)
	})

chokidar
	.watch(path.join(repoRootPath, "app/modules"), {
		ignoreInitial: true,
		ignored: (filePath) => {
			// Must be a Swift file
			const regex = globRegex("**/*.swift")
			if (!regex.test(filePath)) {
				return true
			}

			// Catch most of ignored files
			const ignoredPatterns = ["**/.build/**", "**/Package.swift", "**/Module.swift", "**/*.generated.*.swift"]
			for (const pattern of ignoredPatterns) {
				const regex = globRegex(pattern)
				if (regex.test(filePath)) {
					return true
				}
			}

			// Check git ignore after cheap pattern matching
			try {
				execSync(`git check-ignore ${filePath}`)
				return true
			} catch {
				// The command fails when the file is not ignored.
				return false
			}
		},
	})
	.on("all", (evt, filePath) => {
		try {
			if (isWatcherDisabled()) {
				return
			}
			console.log("changed.", filePath)

			const appPath = path.join(repoRootPath, "app")
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
	.on("error", (error) => {
		console.error("pkg-watch: watcher error:", error)
	})
