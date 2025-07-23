import fs from "fs-extra"
import path from "path"
import os from "os"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const destinations = [
	path.join(os.homedir(), "Library/Application Support/command"),
	path.join(__dirname, "../../app/modules/services/ServerService/Sources/Resources"),
]
const sources = ["./dist/main.bundle.cjs", "./dist/main.bundle.cjs.map", "./build.sha256"]

// Ensure all destination directories exist
for (const dest of destinations) {
	await fs.ensureDir(dest)
}

// Copy each file to all destinations
for (const source of sources) {
	const filename = path.basename(source)
	for (const dest of destinations) {
		const destination = path.join(dest, filename)
		await fs.copy(source, destination)
	}
}

// now copy all the content of node_modules/vscode-material-icons/generated/icons
const iconsDir = path.join(__dirname, "../../app/modules/coreUI/DLS/Sources/Resources/fileIcons/svg")
await fs.ensureDir(iconsDir)
await fs.copy(path.join(__dirname, "../node_modules/vscode-material-icons/generated/icons"), iconsDir)
