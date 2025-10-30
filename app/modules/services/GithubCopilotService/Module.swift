Target.module(
  name: "GithubCopilotService",
  dependencies: [
    "AppFoundation",
    "CodeCompletionFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "GithubCopilotServiceInterface",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  resources: [
    .process("Resources/install-language-server.sh"),
  ])
