import chokidar from "chokidar"
import { execSync, spawn } from "child_process"
import { computeAndSaveHash } from "../build.js"
import generateSwiftSchema from "./generateSwiftSchema.js"
import { existsSync, statSync } from "fs"
import path from "path"
import globRegex from "glob-regex"

const isWatcherDisabled = (): boolean => {
	// The watcher might be temporarily disabled to avoid interfering with other processes.
	return existsSync("../.build/disable-watcher")
}

const repoRootPath = new URL("../../", import.meta.url).pathname
const initiallyTrackedFiles = new Set(execSync(`git ls-files`, { cwd: repoRootPath }).toString().split("\n"))

chokidar
	.watch(path.join(repoRootPath, "local-server/dist/main.bundle.cjs"), { ignoreInitial: true })
	.on("ready", () => {
		console.log(`[READY] Local server bundle watcher initialized`)
	})
	.on("all", async (evt, filePath) => {
		if (isWatcherDisabled()) {
			return
		}
		console.log("changed:", filePath.replace(repoRootPath, ""))

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
	.on("ready", () => {
		console.log(`[READY] Swift schema watcher initialized`)
	})
	.on("all", (evt, filePath) => {
		if (isWatcherDisabled()) {
			return
		}
		console.log("changed:", filePath.replace(repoRootPath, ""))
		try {
			generateSwiftSchema()
		} catch (error) {
			console.error(`Error generating Swift schema: ${error as Error}`)
		}
	})
	.on("error", (error) => {
		console.error("pkg-watch: watcher error:", error)
	})

let isReady = false
let watchedSwiftFiles = 0
chokidar
	.watch(path.join(repoRootPath, "app/modules"), {
		ignoreInitial: true,
		ignored: (filePath, stats) => {
			if (stats?.isDirectory() != false) {
				const ignoredPatterns = ["**/.build/**"]
				for (const pattern of ignoredPatterns) {
					const regex = globRegex(pattern)
					if (regex.test(filePath)) {
						return true
					}
				}
				// Return false to allow for scanning of the directory's content.
				return false
			}
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
			if (!isReady) {
				// Initially we compare to the result of `git ls-files` to avoid making many calls to `git check-ignore`
				// as this function is called once for each tracked file in the directory.
				const isTracked = initiallyTrackedFiles.has(filePath.replace(repoRootPath, ""))
				if (isTracked) {
					watchedSwiftFiles += 1
				}
				return !isTracked
			} else {
				// After the initial scan, we compare to the result of `git check-ignore`, which is cheaper than `git ls-files`
				try {
					execSync(`git check-ignore ${filePath}`)
					return true
				} catch {
					// The command fails when the file is not ignored.
					watchedSwiftFiles += 1
					return false
				}
			}
		},
	})
	.on("ready", () => {
		isReady = true
		console.log(`[READY] Swift file watcher initialized, watching ${watchedSwiftFiles} .swift files`)
	})
	.on("all", (evt, filePath) => {
		try {
			if (evt !== "unlink" && evt !== "unlinkDir" && statSync(filePath).isDirectory()) {
				// Directories are not ignored at the watcher level as this would prevent the watcher from watching the directory's content.
				// So we ignore them in the event handler.
				return
			}

			if (isWatcherDisabled()) {
				return
			}
			console.log("changed:", filePath.replace(repoRootPath, ""))

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
			console.error(`Error watching file changes for ${filePath} ${evt}: ${error as Error}`)
		}
	})
	.on("error", (error) => {
		console.error("pkg-watch: watcher error:", error)
	})
