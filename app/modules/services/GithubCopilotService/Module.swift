Target.module(
  name: "GithubCopilotService",
  dependencies: [
    "AppFoundation",
    "CodeCompletionFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "GithubCopilotServiceInterface",
    "JSONFoundation",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  resources: [
    .process("Resources/install-language-server.sh"),
  ])
