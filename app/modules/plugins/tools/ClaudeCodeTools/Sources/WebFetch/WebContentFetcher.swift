// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LoggingServiceInterface
import WebKit

// MARK: - WebContentFetcher

public class WebContentFetcher: NSObject, WKNavigationDelegate {
  // MARK: - Initialization
  public override init() {
    super.init()
    setupWebView()
  }

  deinit {
    self.loadingTimer?.invalidate()
    let webView = self.webView
    Task { @MainActor in
      webView?.navigationDelegate = nil
      webView?.stopLoading()
    }
  }

  public enum WebContentError: Error, LocalizedError {
    case invalidURL(String)
    case timeout
    case noContent
    case navigationFailed(Error)
    case javascriptError(Error)

    public var errorDescription: String? {
      switch self {
      case .invalidURL(let url): "Invalid URL: \(url)"
      case .timeout: "Request timed out"
      case .noContent: "No content found"
      case .navigationFailed(let error): "Navigation failed: \(error.localizedDescription)"
      case .javascriptError(let error): "JavaScript execution error: \(error.localizedDescription)"
      }
    }
  }

  public static func fetchContentAsync(from urlString: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      let fetcher = WebContentFetcher()
      fetcher.fetchContent(from: urlString) { result in
        withExtendedLifetime(fetcher) {
          continuation.resume(with: result)
        }
      }
    }
  }

  public static func fetchMultipleContentAsync(from urls: [String]) async -> [String] {
    var results = [String]()

    for url in urls {
      do {
        let content = try await fetchContentAsync(from: url)
        results.append("Successfully fetched content from \(url): \(content)")
      } catch {
        defaultLogger.error("Failed to fetch content from \(url)", error)
        results.append("Failed to fetch content from \(url) with error: \(error.localizedDescription)")
      }
    }

    return results
  }

  // MARK: - Public Methods
  public func fetchContent(from urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
      completion(.failure(WebContentError.invalidURL(urlString)))
      return
    }

    self.completion = completion
    setupTimeout()
    loadContent(from: url)
  }

  // MARK: - WKNavigationDelegate
  public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
    loadingTimer?.invalidate()

    DispatchQueue.main.asyncAfter(deadline: .now() + Config.contentLoadDelay) {
      webView.evaluateJavaScript("document.body.innerHTML") { [weak self] result, error in
        DispatchQueue.main.async {
          if let error {
            defaultLogger.error("JavaScript execution error", error)
            self?.completeWithError(WebContentError.javascriptError(error))
            return
          }

          if let html = result as? String, !html.isEmpty {
            self?.processHTML(html)
          } else {
            self?.completeWithError(WebContentError.noContent)
          }
        }
      }
    }
  }

  public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
    handleNavigationFailure(error)
  }

  public func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
    handleNavigationFailure(error)
  }

  private enum Config {
    static let timeout: TimeInterval = 30.0
    static let contentLoadDelay: TimeInterval = 2.0
  }

  private static let converter = HTMLToMarkdownConverter()

  private var webView: WKWebView?
  private var loadingTimer: Timer?
  private var completion: ((Result<String, Error>) -> Void)?

  // MARK: - Private Methods
  private func setupWebView() {
    let configuration = WKWebViewConfiguration()
    let dataSource = WKWebsiteDataStore.nonPersistent()

    configuration.websiteDataStore = dataSource
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView?.navigationDelegate = self
  }

  private func setupTimeout() {
    loadingTimer?.invalidate()
    loadingTimer = Timer.scheduledTimer(withTimeInterval: Config.timeout, repeats: false) { [weak self] _ in
      DispatchQueue.main.async {
        defaultLogger.error("Request timed out")
        self?.completeWithError(WebContentError.timeout)
      }
    }
  }

  private func loadContent(from url: URL) {
    if webView == nil {
      setupWebView()
    }

    guard let webView else {
      completeWithError(WebContentError.navigationFailed(NSError(domain: "WebView creation failed", code: -1)))
      return
    }

    let request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: Config.timeout)
    webView.load(request)
  }

  private func processHTML(_ html: String) {
    do {
      let cleanedText = try Self.converter.convertToMarkdown(from: html)
      completeWithSuccess(cleanedText)
    } catch {
      defaultLogger.error("SwiftSoup parsing error", error)
      completeWithError(error)
    }
  }

  private func completeWithSuccess(_ content: String) {
    completion?(.success(content))
    completion = nil
  }

  private func completeWithError(_ error: Error) {
    completion?(.failure(error))
    completion = nil
  }

  private func handleNavigationFailure(_ error: Error) {
    loadingTimer?.invalidate()
    DispatchQueue.main.async {
      defaultLogger.error("Navigation failed", error)
      self.completeWithError(WebContentError.navigationFailed(error))
    }
  }
}

// MARK: - Timer + @unchecked @retroactive Sendable

extension Timer: @unchecked @retroactive Sendable { }
