import fs from "fs-extra"
import path from "path"
import os from "os"
import { fileURLToPath } from "url"
import { spawn } from "child_process"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const copyJSCodeToApp = async () => {
	const destinations = [
		path.join(os.homedir(), "Library/Application Support/dev.getcmd.debug.command"),
		path.join(__dirname, "../../app/modules/services/LocalServerService/Sources/Resources"),
	]
	const sources = ["./dist/main.bundle.cjs.gz", "./dist/main.bundle.cjs.map", "./build.sha256"]

	// Ensure all destination directories exist
	for (const dest of destinations) {
		await fs.ensureDir(dest)
	}

	// Copy each file to all destinations
	for (const source of sources) {
		const filename = path.basename(source)
		for (const dest of destinations) {
			const destination = path.join(dest, filename)
			if (fs.existsSync(source)) {
				await fs.copy(source, destination)
			} else {
				try {
					await fs.unlink(destination)
				} catch {
					// Ignore errors if the file doesn't exist
				}
			}
		}
	}
}

// now copy all the content of node_modules/vscode-material-icons/generated/icons
const copyIconsToApp = async () => {
	const iconsDir = path.join(__dirname, "../../app/modules/coreUI/DLS/Sources/Resources/fileIcons")
	await fs.ensureDir(iconsDir)
	const srcIconsDir = path.join(__dirname, "../node_modules/vscode-material-icons/generated/icons")

	// Compress the icons directory using tar via spawn
	// For deterministic archives with BSD tar, copy files to temp dir with fixed timestamps
	const tmpDir = path.join(os.tmpdir(), "icons-tmp")
	await fs.remove(tmpDir)
	await fs.ensureDir(tmpDir)
	await fs.copy(srcIconsDir, tmpDir, { overwrite: true })

	// Set all files to epoch time for deterministic archive
	// Use UTC timezone to ensure consistent timestamps across all environments
	await new Promise<void>((resolve, reject) => {
		const touchProcess = spawn("sh", ["-c", `TZ=UTC find ${tmpDir} -exec touch -t 197001010000 {} +`])
		touchProcess.on("error", reject)
		touchProcess.on("close", (code) => {
			if (code === 0) resolve()
			else reject(new Error(`touch process exited with code ${code}`))
		})
	})

	// Create deterministic tar archive
	const archivePath = path.join(iconsDir, "icons.tar.gz")
	await new Promise<void>((resolve, reject) => {
		const tarProcess = spawn("sh", [
			"-c",
			`cd ${tmpDir} && find . -type f | sort | tar -cf - -T - --uid 0 --gid 0 --uname root --gname root --no-mac-metadata --no-xattrs | gzip -n > ${archivePath}`,
		])
		tarProcess.on("error", reject)
		tarProcess.on("close", (code) => {
			if (code === 0) resolve()
			else reject(new Error(`tar process exited with code ${code}`))
		})
	})

	// Verify archive is not empty
	const stats = await fs.stat(archivePath)
	const minSize = 10 * 1024 // 10KB minimum
	if (stats.size < minSize) {
		throw new Error(
			`Archive is too small (${stats.size} bytes). Expected at least ${minSize} bytes. Archive creation may have failed.`,
		)
	}

	// Clean up temp directory
	await fs.remove(tmpDir)
}

await copyJSCodeToApp()
await copyIconsToApp()
