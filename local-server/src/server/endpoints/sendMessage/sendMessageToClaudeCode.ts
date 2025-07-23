import { logError, logInfo } from "@/logger"
import { LocalExecutable, Message } from "@/server/schemas/sendMessageSchema"
import { CoreMessage, CoreUserMessage } from "ai"
import { spawn, exec } from "child_process"
import { Response } from "express"
import { exit } from "process"

export const sendMessageToClaudeCode = async (
	messages: CoreMessage[],
	localExecutable: LocalExecutable,
	res: Response,
) => {
	return new Promise<void>((resolve, reject) => {
		let firstNewUserMessagesIdx = messages.length
		while (firstNewUserMessagesIdx > 0 && messages[firstNewUserMessagesIdx - 1].role === "user") {
			firstNewUserMessagesIdx--
		}
		logInfo(`First new user messages index: ${firstNewUserMessagesIdx} / Total messages: ${messages.length}`)

		const newUserMessages = messages.slice(firstNewUserMessagesIdx).filter(isCoreUserMessage)
		const newUserMessagesText = newUserMessages
			.map((message) => {
				if (typeof message.content === "string") {
					return message.content
				}
				return message.content
					.map((content) => {
						if (content.type === "text") {
							return content.text
						}
						return undefined
					})
					.filter(Boolean)
					.join("\n")
			})
			.join("\n")

		logInfo(`Spawning Claude with executable: ${localExecutable.executable}`)
		logInfo(`New user messages text: "${newUserMessagesText}"`)

		// call `claude --output-format stream-json --print "foo"`
		logInfo(`About to spawn process...`)
		const args = ["help"]
		logInfo(`Full command: ${localExecutable.executable} ${args.join(" ")}`)

		// Try using exec instead as a fallback
		const command = `${localExecutable.executable} ${args.join(" ")}`
		logInfo(`Trying exec approach with command: ${command}`)

		const child = spawn(localExecutable.executable, args, {
			stdio: ["pipe", "pipe", "pipe"],
			env: localExecutable.env,
			shell: false,
			cwd: localExecutable.cwd,
		})
		logInfo(`Process spawned with PID: ${child.pid}`)

		// No need to write to stdin when using -p flag

		child.on("error", (err) => {
			logError(`Failed to spawn Claude process: ${err.message}`)
		})

		child.on("spawn", () => {
			logInfo(`Claude process successfully spawned`)
		})

		// Add a timeout to prevent hanging indefinitely
		const timeout = setTimeout(() => {
			logError(`Claude process timed out after 30 seconds, killing process`)
			child.kill("SIGTERM")
			reject(new Error("Claude process timed out"))
		}, 10000)

		child.stdout.setEncoding("utf8")
		child.stderr.setEncoding("utf8")

		child.stdout.on("data", (data) => {
			const output = data.toString()
			logInfo(`Received output from Claude: ${output}`)
		})

		child.stderr.on("data", (data) => {
			const error = data.toString()
			logError(`Received error from Claude: ${error}`)
		})

		child.on("close", (code) => {
			clearTimeout(timeout)
			logInfo(`Claude process exited with code ${code}`)
			resolve()
		})

		child.on("exit", (code, signal) => {
			clearTimeout(timeout)
			logInfo(`Claude process exit event: code=${code}, signal=${signal}`)
			resolve()
		})
	})
}

export const isCoreUserMessage = (message: CoreMessage): message is CoreUserMessage => {
	return message.role === "user"
}

sendMessageToClaudeCode(
	[
		{
			role: "user",
			content: [
				{
					type: "text",
					text: "can you sumarrize the readme",
				},
			],
		},
	],
	{
		executable: "claude",
		env: {
			PATH: "/Users/guigui/.bun/bin:/Users/guigui/Library/pnpm:/Users/guigui/.codeium/windsurf/bin:/Users/guigui/.nvm/versions/node/v22.13.1/bin:/Users/guigui/Library/:/Users/guigui/homebrew/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/Users/guigui/.cargo/bin:/Users/guigui/.local/bin:/Applications/Visual Studio Code.app/Contents/Resources/app/bin:/opt/homebrew/bin",
			_: "/usr/bin/printenv",
			BUN_INSTALL: "/Users/guigui/.bun",
			SHELL: "/bin/zsh",
			XPC_FLAGS: "0x0",
			CLICOLOR: "1",
			OPEN_ROUTER_LOCAL_SERVER_PROXY: "http://localhost:10002/api/v1",
			NVM_BIN: "/Users/guigui/.nvm/versions/node/v22.13.1/bin",
			XPC_SERVICE_NAME:
				"application.dev.getcmd.debug.command.73895200.74181292.E512B068-A442-4FC0-8B18-B760F3E8C5BF",
			LLVM_PROFILE_FILE: "/dev/null",
			LOGNAME: "guigui",
			CA_ASSERT_MAIN_THREAD_TRANSACTIONS: "0",
			__XPC_LLVM_PROFILE_FILE: "/dev/null",
			COMMAND_MODE: "unix2003",
			NSUnbufferedIO: "YES",
			PERFC_SUPPRESS_SYSTEM_REPORTS: "1",
			PWD: "/",
			HOME: "/Users/guigui",
			__XPC_DYLD_LIBRARY_PATH:
				"/Users/guigui/Library/Developer/Xcode/DerivedData/command-ftrgnbimkwrtspgqxsaqifauilvv/Build/Products/Debug",
			OPENAI_LOCAL_SERVER_PROXY: "http://localhost:10003/v1",
			__XCODE_BUILT_PRODUCTS_DIR_PATHS:
				"/Users/guigui/Library/Developer/Xcode/DerivedData/command-ftrgnbimkwrtspgqxsaqifauilvv/Build/Products/Debug",
			NVM_INC: "/Users/guigui/.nvm/versions/node/v22.13.1/include/node",
			NVM_DIR: "/Users/guigui/.nvm",
			SWIFTUI_VIEW_DEBUG: "287",
			USER: "guigui",
			__CF_USER_TEXT_ENCODING: "0x1F5:0x0:0x0",
			CFLOG_FORCE_DISABLE_STDERR: "1",
			OLDPWD: "/",
			TMPDIR: "/var/folders/fv/6rnsg5fs30bgdtylq_bm20bw0000gn/T/",
			ANTHROPIC_LOCAL_SERVER_PROXY: "http://localhost:10001/v1",
			CA_DEBUG_TRANSACTIONS: "0",
			PNPM_HOME: "/Users/guigui/Library/pnpm",
			IDE_DISABLED_OS_ACTIVITY_DT_MODE: "1",
			OS_ACTIVITY_TOOLS_PRIVACY: "YES",
			OS_ACTIVITY_TOOLS_OVERSIZE: "YES",
			SQLITE_ENABLE_THREAD_ASSERTIONS: "1",
			TERM: "dumb",
			NVM_CD_FLAGS: "-q",
			__CFBundleIdentifier: "dev.getcmd.debug.command",
			LS_COLORS: "di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43",
			METAL_DEBUG_ERROR_MODE: "0",
			METAL_DEVICE_WRAPPER_TYPE: "1",
			SHLVL: "0",
			CORESVG_VERBOSE: "1",
			LESS: "-R",
			__XPC_DYLD_FRAMEWORK_PATH:
				"/Users/guigui/Library/Developer/Xcode/DerivedData/command-ftrgnbimkwrtspgqxsaqifauilvv/Build/Products/Debug",
			ZSH: "/Users/guigui/.oh-my-zsh",
			MallocNanoZone: "1",
			PAGER: "less",
			LSCOLORS: "ExFxBxDxCxegedabagacad",
			SSH_AUTH_SOCK: "/private/tmp/com.apple.launchd.f33Oib5v4u/Listeners",
		},
		cwd: "/Users/guigui/dev/cmd.git/cc-provider/app",
	},
	null as unknown as Response,
)
	.then(() => {
		logInfo(`sendMessageToClaudeCode completed successfully`)
		exit(0)
	})
	.catch((error) => {
		logError(`sendMessageToClaudeCode failed: ${error.message}`)
		exit(1)
	})
