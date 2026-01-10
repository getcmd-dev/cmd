# Local Server

TypeScript server embedded in CMD that provides AI integration and third-party library access not available in Swift.

## Purpose

This local HTTP server runs alongside the CMD macOS app and handles:
- AI provider integrations (Anthropic, OpenAI, Groq, Gemini, OpenRouter, Ollama)
- Agent Client Protocol (ACP) support
- Model Context Protocol (MCP) support
- File operations and search
- Checkpoint management for conversation state

## Development

```bash
# Run in development mode
yarn run

# Build for production
yarn build:prod

# Run tests
yarn test

# Watch mode with hot reload
yarn watch
```

## Architecture

- **Express server** on port 10534
- **WebSocket support** for real-time communication
- **Process attachment** to automatically exit when parent process dies
- **Error tracking** with Sentry integration

## Key Components

- `/endpoints` - HTTP API endpoints for various features
- `/providers` - AI provider implementations
- `/services` - Business logic and utilities
- `/client` - Client-side integration code
- `/schemas` - Type definitions and validation

The server is built to production and copied to the Swift app bundle during the build process.
