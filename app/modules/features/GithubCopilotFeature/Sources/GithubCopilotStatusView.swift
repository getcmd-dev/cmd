// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - GithubCopilotStatusView

struct GithubCopilotStatusView: View {
  let viewModel: GithubCopilotStatusViewModel

  var body: some View {
    VStack(spacing: 20) {
      // Header
      VStack {
        Image(systemName: "cpu")
          .imageScale(.large)
          .font(.system(size: 48))
          .foregroundStyle(.blue)

        Text("GitHub Copilot Integration")
          .font(.title)
          .fontWeight(.bold)

        Text("Test App")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .padding(.top)

      Divider()

      // Status Section
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Status:")
            .fontWeight(.semibold)
          Spacer()
          statusBadge
        }

        if let username = viewModel.username {
          HStack {
            Text("User:")
              .fontWeight(.semibold)
            Text(username)
            Spacer()
          }
        }

        if let error = viewModel.error {
          HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
          .padding(8)
          .background(Color.red.opacity(0.1))
          .cornerRadius(8)
        }

        if let signInInfo = viewModel.signInInfo {
          VStack(alignment: .leading, spacing: 8) {
            Text("Sign In Required")
              .fontWeight(.semibold)

            HStack {
              VStack(alignment: .leading) {
                Text("1. Visit:")
                  .font(.caption)
                Text(signInInfo.verificationUri)
                  .font(.system(.body, design: .monospaced))
                  .textSelection(.enabled)
              }
            }

            HStack {
              VStack(alignment: .leading) {
                Text("2. Enter code:")
                  .font(.caption)
                Text(signInInfo.userCode)
                  .font(.system(.title2, design: .monospaced))
                  .fontWeight(.bold)
                  .textSelection(.enabled)
              }
            }
          }
          .padding()
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
        }
      }
      .padding(.horizontal)

      Divider()

      // Actions
      VStack(spacing: 12) {
        if !viewModel.isInitialized {
//                    Button(action: {
//                        Task {
//                            await viewModel.initialize()
//                        }
//                    }) {
//                        HStack {
//                            if viewModel.isInitializing {
//                                ProgressView()
//                                    .scaleEffect(0.8)
//                            } else {
//                                Image(systemName: "power")
//                            }
//                            Text(viewModel.isInitializing ? "Initializing..." : "Initialize Copilot")
//                        }
//                        .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .disabled(viewModel.isInitializing)
        } else {
          // Authentication buttons
          if case .loggedOut = viewModel.authStatus {
            Button(action: {
              Task {
                try await viewModel.startSignIn()
              }
            }) {
              HStack {
                Image(systemName: "person.badge.key")
                Text("Start Sign In")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }

          if viewModel.signInInfo != nil {
            Button(action: {
              Task {
                try await viewModel.confirmSignIn()
              }
            }) {
              HStack {
                Image(systemName: "checkmark.circle")
                Text("Confirm Sign In")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          }

          if case .loggedIn(user: _) = viewModel.authStatus {
            Button(action: {
              Task {
                await viewModel.testCompletion()
              }
            }) {
              HStack {
                Image(systemName: "wand.and.stars")
                Text("Test Completion")
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }

          HStack {
            if case .loggedIn(user: _) = viewModel.authStatus {
              Button(action: {
                Task {
                  await viewModel.signOut()
                }
              }) {
                HStack {
                  Image(systemName: "rectangle.portrait.and.arrow.right")
                  Text("Sign Out")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
            }
          }

          Button(action: {
            showConsole = true
          }) {
            HStack {
              Image(systemName: "terminal")
              Text("View Console Logs")
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(.horizontal)

      Spacer()

      // Footer
      Text("Check Xcode console for detailed logs")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom)
    }
    .padding()
  }

  @State private var showConsole = false

  private var statusBadge: some View {
    HStack {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
      Text(statusText)
        .font(.caption)
        .fontWeight(.medium)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(statusColor.opacity(0.2))
    .cornerRadius(12)
  }

  private var statusColor: Color {
    switch viewModel.authStatus {
    case .loggedIn(user: _):
      .green
    case .loggedOut:
      .orange
    case .loggingIn:
      .blue
    }
  }

  private var statusText: String {
    switch viewModel.authStatus {
    case .loggedIn(user: _):
      "Authenticated"
    case .loggedOut:
      "Not Signed In"
    case .loggingIn:
      "Logging in"
    }
  }
}

// MARK: - ConsoleView

struct ConsoleView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack {
      HStack {
        Text("Console Logs")
          .font(.headline)
        Spacer()
        Button("Close") {
          dismiss()
        }
      }
      .padding()

      Text("All logs are printed to Xcode console.\nUse Xcode's Console pane to view them.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding()

      Spacer()
    }
    .frame(minWidth: 400, minHeight: 200)
  }
}
