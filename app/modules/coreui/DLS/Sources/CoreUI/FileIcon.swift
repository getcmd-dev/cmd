// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import FoundationInterfaces
import LocalServerServiceInterface
import ShellServiceInterface
import SwiftUI

// MARK: - FileIcon

/// A view that displays an icon for a file.
@MainActor
public struct FileIcon: View {

  public init(filePath: URL) {
    self.filePath = filePath
    language = Self.language(for: filePath)
    let cachedImage = Self.cachedImages[language]
    image = ObservableValue<NSImage?>(cachedImage)
    if cachedImage == nil {
      Task { [self] in
        image.value = try await Self.fetchImage(for: language, filePath: filePath, server: server)
      }
    }
  }

  public let language: String
  public let placeholder = NSImage(systemSymbolName: "text.document", accessibilityDescription: "Unknown file type")!

  public var body: some View {
    Image(nsImage: image.value ?? placeholder)
      .resizable()
      .interpolation(.none)
      .scaledToFit()
  }

  /// Returns the language for the given file, inferred from its extension
  public static func language(for filePath: URL) -> String {
    let fileName = filePath.lastPathComponent
    let fileExtension = fileName.split(separator: ".").last.map { String($0) } ?? fileName
    if fileExtensionToLanguage == nil {
      guard let url = resourceBundle.url(forResource: "extensionToLanguage", withExtension: "json") else {
        assertionFailure("The bundle resource `extensionToLanguage.json` could not be read.")
        return fileName
      }
      fileExtensionToLanguage = try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
    return fileExtensionToLanguage?[".\(fileExtension)"] ?? fileExtension
  }

  let filePath: URL

  private static var fileExtensionToLanguage: [String: String]?

  @Bindable private var image: ObservableValue<NSImage?>

  @Dependency(\.localServer) private var server
}

extension FileIcon {

  /// Returns the image for the given language, if one was bundled in the app.
  fileprivate static func bundleImage(for language: String) -> NSImage? {
    resourceBundle.image(forResource: "\(language)-preferred")
  }

  /// Fetches the image for the given language from the internet.
  fileprivate static func fetchImage(for language: String, filePath: URL, server: LocalServer) async throws -> NSImage {
    if let image = bundleImage(for: language) {
      cachedImages[language] = image
      return image
    }
    // While the icons are bundle in the app, the mapping from a filePath
    // to an icon is defined in the node package from
    // https://github.com/material-extensions/vscode-material-icon-theme .
    // So we fetch it over the local server.
    let payload = """
      {
        "path": "\(filePath.path())",
        "type": "file"
      }
      """.utf8Data

    let response: IconResponse = try await server.postRequest(path: "/icon", data: payload)

    @Dependency(\.fileManager) var fileManager
    let iconsPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("command")
      .appendingPathComponent("icons")
    try fileManager.createDirectory(atPath: iconsPath.path, withIntermediateDirectories: true)

    let iconPath = iconsPath.appendingPathComponent(response.iconPath).standardized
    if !fileManager.fileExists(atPath: iconPath.path) {
      try await extractIcons(to: iconsPath)
    }
    guard fileManager.fileExists(atPath: iconPath.path) else {
      throw URLError(.badURL)
    }

    let image = try SVGImageLoader.svg(atPath: iconPath.path)
    cachedImages[language] = image
    return image
  }

  @MainActor private static var cachedImages = [String: NSImage]()

  private static func extractIcons(to path: URL) async throws {
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.shellService) var shellService
    guard let bundlePath = resourceBundle.path(forResource: "icons.tar.gz", ofType: nil) else {
      throw URLError(.badURL)
    }
    let tarDestinationPath = path.deletingLastPathComponent().appendingPathComponent("icons.tar.gz").path
    do {
      try fileManager.removeItem(atPath: tarDestinationPath)
    } catch { }
    try fileManager.copyItem(atPath: bundlePath, toPath: tarDestinationPath)
    try await shellService.run("tar -xzf '\(tarDestinationPath)' -C '\(path.path)'")
  }

}

// MARK: - IconResponse

private struct IconResponse: Decodable {
  let iconPath: String
}

#if SWIFT_PACKAGE
// TODO: look if the later also works
private let resourceBundle = Bundle.module
#else
private class ResourceBundle { }
private let resourceBundle = Bundle(for: ResourceBundle.self)
#endif

#Preview {
  VStack {
    VStack(spacing: 10) {
      FileIcon(filePath: URL(filePath: "/path/to/file.swift"))
        .frame(width: 30, height: 30)
      FileIcon(filePath: URL(filePath: "/path/to/file.js"))
        .frame(width: 30, height: 30)
      Rectangle()
        .frame(width: 30, height: 30)
    }
    .padding()
  }
}
