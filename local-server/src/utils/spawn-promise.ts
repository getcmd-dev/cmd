import { spawn as _spawn } from "child_process"

export function spawn(
	command: string,
	options: { args?: string[]; env?: Record<string, string>; cwd?: string } = {},
): Promise<{ stdout: string; stderr: string; code: number }> {
	return new Promise((resolve, reject) => {
		let cmd = command
		let cmdArgs = options.args
		if (cmdArgs == undefined) {
			const spl = cmd.split(" ").filter((s) => s.length > 0)

			cmd = spl[0]
			cmdArgs = spl.slice(1)
		}

		const child = _spawn(cmd, cmdArgs, {
			cwd: options.cwd,
			env: options.env,
		})

		let stdout = ""
		let stderr = ""

		child.stdout.on("data", (data) => {
			stdout += data.toString()
		})

		child.stderr.on("data", (data) => {
			stderr += data.toString()
		})

		child.on("close", (code) => {
			if (code === 0) {
				resolve({ stdout, stderr, code })
			} else {
				reject(new Error(`Command exited with code ${code}: ${stderr}`))
			}
		})

		child.on("error", (err) => {
			reject(err)
		})
	})
}
