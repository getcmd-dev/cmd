import fs from "fs-extra"
import path from "path"
import os from "os"
import { fileURLToPath } from "url"
import { spawn } from "child_process"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const destinations = [
	path.join(os.homedir(), "Library/Application Support/command"),
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

// now copy all the content of node_modules/vscode-material-icons/generated/icons
const iconsDir = path.join(__dirname, "../../app/modules/coreUI/DLS/Sources/Resources/fileIcons")
await fs.ensureDir(iconsDir)
const srcIconsDir = path.join(__dirname, "../node_modules/vscode-material-icons/generated/icons")

// Compress the icons directory using tar via spawn
await new Promise<void>((resolve, reject) => {
	const tarProcess = spawn("sh", ["-c", `tar cf - ${srcIconsDir} | gzip -n > ${path.join(iconsDir, "icons.tar.gz")}`])
	tarProcess.on("error", reject)
	tarProcess.on("close", (code) => {
		if (code === 0) resolve()
		else reject(new Error(`tar process exited with code ${code}`))
	})
})
