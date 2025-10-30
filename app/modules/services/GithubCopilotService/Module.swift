Target.module(
  name: "GithubCopilotService",
  dependencies: [
    "AppFoundation",
    "CodeCompletionFoundation",
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  resources: [
    .process("Resources/install-language-server.sh"),
  ])
