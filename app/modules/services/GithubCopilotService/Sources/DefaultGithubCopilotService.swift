// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import DependencyFoundation
import Foundation
import FoundationInterfaces
import GithubCopilotServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

// MARK: - DefaultGithubCopilotService

@ThreadSafe
final class DefaultGithubCopilotService: GithubCopilotService {

  init(shellService: ShellService, fileManager: FileManagerI) {
    self.shellService = shellService
    self.fileManager = fileManager

    let (executablePath, setExecutablePath) = Future<URL, Error>.make()
    self.executablePath = executablePath
    self.setExecutablePath = setExecutablePath

    let (authServer, setAuthServer) = Future<GithubCopilotServer, Error>.make()
    self.authServer = authServer
    self.setAuthServer = setAuthServer

    Task {
      try await setup()
    }
  }

  var _loginStatus = CurrentValueSubject<LoginStatus, Never>(.loggedOut)

  let executablePath: Future<URL, Error>
  let setExecutablePath: @Sendable (Result<URL, Error>) -> Void
  let authServer: Future<GithubCopilotServer, Error>
  let setAuthServer: @Sendable (Result<GithubCopilotServer, Error>) -> Void

  private var cancellables = Set<AnyCancellable>()
  private let executableVersion = "1.389.0"

  private let shellService: ShellService
  private let fileManager: FileManagerI

  private func setup() async throws {
    print("init!!")
    do {
      let executablePath = try await install()
      setExecutablePath(.success(executablePath))
      let authServer = GithubCopilotServer(
        executablePath: executablePath,
        // Use this folder that we know to exist as the workspace root, as we need to provide one
        workspaceRoot: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".cmd"),
        shellService: shellService,
        fileManager: fileManager)
      setAuthServer(.success(authServer))
      authServer.notifications.sink { @Sendable [weak self] notification in
        self?.handle(authServerNotification: notification)
      }.store(in: &cancellables)
    } catch {
      setExecutablePath(.failure(error))
      setAuthServer(.failure(error))
      defaultLogger.error("Failed to initialize Github Copilot: \(error)", error)
    }

    _ = try await checkStatus()
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
          defaultLogger.error("Failed to handle auth server didChangeStatus notification", error)
        }
      }
    }
  }

  private func install() async throws -> URL {
    guard
      let executablePath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent(Bundle.main.hostAppBundleId)
        .appendingPathComponent("copilot-language-server-\(executableVersion)")
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
  Self: ShellServiceProviding
{
  public var githubCopilotService: GithubCopilotService {
    shared {
      DefaultGithubCopilotService(
        shellService: self.shellService,
        fileManager: self.fileManager)
    }
  }

}

private let resourceBundle = Bundle.module
