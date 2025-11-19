// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
@preconcurrency import Combine
import DependencyFoundation
import Foundation
import FoundationInterfaces
import GithubCopilotServiceInterface
import JRPCServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

let executableVersion = "1.396.0"

extension FileManagerI {
  var expectedExecutablePath: URL? {
    urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(Bundle.main.hostAppBundleId)
      .appendingPathComponent("copilot-language-server-\(executableVersion)")
  }
}

// MARK: - DefaultGithubCopilotService

@ThreadSafe
final class DefaultGithubCopilotService: GithubCopilotService {
  init(shellService: ShellService, fileManager: FileManagerI, jrpcService: JRPCService) {
    self.shellService = shellService
    self.fileManager = fileManager
    self.jrpcService = jrpcService
    logger = defaultLogger.subLogger(subsystem: "githubCopilotService")
    let expectedExecutablePath = fileManager.expectedExecutablePath
    self.expectedExecutablePath = expectedExecutablePath

    let currentVersionInstalled = expectedExecutablePath.map { fileManager.fileExists(atPath: $0.path) } ?? false
    let hasAnyVersionInstalled = Self.hasAnyLSPServerVersion(fileManager: fileManager)

    _isLSPServerInstalled = CurrentValueSubject<Bool, Never>(currentVersionInstalled)

    let (executablePath, setExecutablePath) = Future<URL, Error>.make()
    self.executablePath = executablePath
    self.setExecutablePath = setExecutablePath

    let (authServer, setAuthServer) = Future<GithubCopilotServer, Error>.make()
    self.authServer = authServer
    self.setAuthServer = setAuthServer

    // Install if either:
    // 1. Current version is already installed (need to start auth server)
    // 2. A previous version exists but current version doesn't (need to upgrade)
    if currentVersionInstalled || hasAnyVersionInstalled {
      Task {
        try await installLSPServer()
      }
    }
  }

  let logger: Logger

  var _loginStatus = CurrentValueSubject<LoginStatus, Never>(.loggedOut)
  var _isLSPServerInstalled: CurrentValueSubject<Bool, Never>

  let executablePath: Future<URL, Error>
  let setExecutablePath: @Sendable (Result<URL, Error>) -> Void
  let authServer: Future<GithubCopilotServer, Error>
  let setAuthServer: @Sendable (Result<GithubCopilotServer, Error>) -> Void

  var displayName: String { "GitHub Copilot" }

  var isAvailable: Bool {
    isLSPServerInstalled.currentValue
  }

  var isLSPServerInstalled: ReadonlyCurrentValueSubject<Bool> {
    _isLSPServerInstalled.readonly()
  }

  func setUp(workspace: Workspace) {
    do {
      // Start the server and cache the connection
      _ = try lspServer(for: workspace)
    } catch { }
  }

  func close(workspace: URL) {
    // TODO: test that this closes the stdio connection.
    servers.removeValue(forKey: workspace)
  }

  func installLSPServer() async throws {
    do {
      let executablePath = try await downloadExecutableIfNeeded()
      setExecutablePath(.success(executablePath))
      let authServer = GithubCopilotServer(
        executablePath: executablePath,
        // Use this folder that we know to exist as the workspace root, as we need to provide one
        workspace: FrozenWorkspace(
          url: URL(filePath: "/"),
          root: URL(filePath: "/"),
          files: []),
        shellService: shellService,
        fileManager: fileManager,
        jrpcService: jrpcService)
      setAuthServer(.success(authServer))
      authServer.notifications.sink { @Sendable [weak self] notification in
        self?.handle(authServerNotification: notification)
      }.store(in: &cancellables)
    } catch {
      setExecutablePath(.failure(error))
      setAuthServer(.failure(error))
      logger.error("Failed to initialize Github Copilot: \(error)", error)
    }
    _isLSPServerInstalled.send(true)

    _ = try await checkStatus()
  }

  /// Returns the LSP server for the given workspace.
  func lspServer(for workspace: Workspace) throws -> GithubCopilotServer {
    guard let expectedExecutablePath else {
      throw AppError("Path for Copilot language server executable not found")
    }
    if let server = servers[workspace.url] {
      return server
    }
    guard _isLSPServerInstalled.value else {
      throw AppError("Copilot LSP server is not installed")
    }
    let server = GithubCopilotServer(
      executablePath: expectedExecutablePath,
      workspace: workspace,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: jrpcService)
    servers[workspace.url] = server
    return server
  }

  private var cancellables = Set<AnyCancellable>()

  private let shellService: ShellService
  private let fileManager: FileManagerI
  private let jrpcService: JRPCService

  private let expectedExecutablePath: URL?

  /// Each workspace needs its own LSP server instance
  private var servers = [URL: GithubCopilotServer]()

  /// Checks if any version of the LSP server has been installed previously
  private static func hasAnyLSPServerVersion(fileManager: FileManagerI) -> Bool {
    guard
      let dirPath = fileManager.expectedExecutablePath?.deletingLastPathComponent(),
      let contents = try? fileManager.contentsOfDirectory(at: dirPath)
    else { return false }

    return contents.contains { $0.lastPathComponent.hasPrefix("copilot-language-server-") }
  }

  /// Removes old versions of the LSP server, keeping only the current version
  private func cleanupOldVersions() {
    guard
      let dirPath = fileManager.expectedExecutablePath?.deletingLastPathComponent(),
      let contents = try? fileManager.contentsOfDirectory(at: dirPath).map(\.lastPathComponent)
    else { return }

    let currentVersionName = "copilot-language-server-\(executableVersion)"
    let oldVersions = contents.filter { $0.hasPrefix("copilot-language-server-") && $0 != currentVersionName }

    for oldVersion in oldVersions {
      let oldVersionPath = dirPath.appendingPathComponent(oldVersion)
      do {
        try fileManager.removeItem(atPath: oldVersionPath.path)
        logger.info("Removed old LSP server version: \(oldVersion)")
      } catch {
        logger.error("Failed to remove old LSP server version \(oldVersion): \(error)", error)
      }
    }
  }

  private func handle(authServerNotification: JRPCNotification) {
    if authServerNotification.method == "didChangeStatus" {
      Task {
        do {
          let params = try authServerNotification.params?.decode(as: DidChangeStatusNotificationParams.self)
          if params?.kind == "Normal", !_loginStatus.value.isLoggedIn {
            _ = try await checkStatus()
          } else if params?.kind != "Normal", _loginStatus.value.isLoggedIn {
            _ = try await checkStatus()
          }
        } catch {
          logger.error("Failed to handle auth server didChangeStatus notification", error)
        }
      }
    }
  }

  private func downloadExecutableIfNeeded() async throws -> URL {
    guard
      let executablePath = expectedExecutablePath
    else {
      throw AppError("Path for Copilot language server executable not found")
    }

    if !fileManager.fileExists(atPath: executablePath.path) {
      // Install the language server if the executable has not already been installed
      guard
        let installScriptPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
          .appendingPathComponent(Bundle.main.hostAppBundleId)
          .appendingPathComponent("install-copilot-language-server.sh")
      else {
        throw AppError("Path for Copilot language server install script not found")
      }
      guard let installationScript = resourceBundle.url(forResource: "install-language-server", withExtension: "sh") else {
        throw AppError("Copilot language server installation script not found in bundle")
      }
      // Copy installation script to Application Support
      if fileManager.fileExists(atPath: installScriptPath.path) {
        try fileManager.removeItem(atPath: installScriptPath.path)
      }
      try fileManager.copyItem(atPath: installationScript.path, toPath: installScriptPath.path)
      try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installScriptPath.path)

      var env = await shellService.env
      env["COPILOT_LANGUAGE_SERVER_VERSION"] = executableVersion
      env["COPILOT_LANGUAGE_SERVER_INSTALL_PATH"] = executablePath.path
      try await shellService.runAndThrows("/bin/bash \"\(installScriptPath.path)\"", env: env)

      // Clean up old versions after successful installation
      cleanupOldVersions()
    }

    if !fileManager.fileExists(atPath: executablePath.path) {
      throw AppError("Failed to install Copilot language server executable")
    }
    return executablePath
  }

}

extension LoginStatus {
  var isLoggedIn: Bool {
    switch self {
    case .loggedIn:
      true
    default:
      false
    }
  }
}

extension BaseProviding where
  Self: FileManagerProviding,
  Self: ShellServiceProviding,
  Self: JRPCServiceProviding
{
  public var githubCopilotService: GithubCopilotService {
    shared {
      DefaultGithubCopilotService(
        shellService: shellService,
        fileManager: fileManager,
        jrpcService: jrpcService)
    }
  }

}

private let resourceBundle = Bundle.module
