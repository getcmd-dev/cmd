// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import Foundation
import FoundationInterfaces
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

@ThreadSafe
public final class GithubCopilotService: Sendable {

  init(workspaceRoot: URL, shellService: ShellService, fileManager: FileManagerI) {
    self.workspaceRoot = workspaceRoot
    self.shellService = shellService
    self.fileManager = fileManager

    let (executablePath, setExecutablePath) = Future<URL, Error>.make()
    self.executablePath = executablePath
    self.setExecutablePath = setExecutablePath

    let (authServer, setAuthServer) = Future<GithubCopilotServer, Error>.make()
    self.authServer = authServer
    self.setAuthServer = setAuthServer

    Task {
      do {
        let executablePath = try await self.install()
        setExecutablePath(.success(executablePath))
        let authServer = GithubCopilotServer(
          executablePath: executablePath,
          workspaceRoot: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".cmd"),
          shellService: shellService,
          fileManager: fileManager)
        setAuthServer(.success(authServer))
      } catch {
        setExecutablePath(.failure(error))
        setAuthServer(.failure(error))
      }

      _ = try await self.checkStatus()
    }
  }

  var _loginStatus = CurrentValueSubject<LoginStatus, Never>(.loggedOut)

  let executablePath: Future<URL, Error>
  let setExecutablePath: @Sendable (Result<URL, Error>) -> Void
  let authServer: Future<GithubCopilotServer, Error>
  let setAuthServer: @Sendable (Result<GithubCopilotServer, Error>) -> Void

  private let executableVersion = "1.389.0"

  private let shellService: ShellService
  private let workspaceRoot: URL
  private let fileManager: FileManagerI

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
      guard let installationScript = Bundle.main.url(forResource: "install-copilot-language-server", withExtension: "sh") else {
        throw AppError("Copilot language server installation script not found in bundle")
      }
      // Copy installation script to Application Support
      try fileManager.copyItem(atPath: installationScript.path, toPath: installScriptPath.path)
      var env = await shellService.env
      env["COPILOT_LANGUAGE_SERVER_VERSION"] = executableVersion
      env["COPILOT_LANGUAGE_SERVER_INSTALL_PATH"] = executablePath.path
      try await shellService.run("/bin/bash \"\(installScriptPath.path)\"", env: env)
    }

    if !fileManager.fileExists(atPath: executablePath.path) {
      throw AppError("Failed to install Copilot language server executable")
    }
    return executablePath
  }
}
