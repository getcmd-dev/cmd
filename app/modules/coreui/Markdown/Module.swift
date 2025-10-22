Target.module(
  name: "Markdown",
  dependencies: [
    .product(name: "Down", package: "Down"),
    "DLS",
    "LoggingServiceInterface",
  ],
  testsDependencies: [
    "Markdown",
  ])
