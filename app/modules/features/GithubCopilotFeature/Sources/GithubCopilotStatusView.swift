// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import GithubCopilotServiceInterface
import SwiftUI

// MARK: - GithubCopilotStatusView

struct GithubCopilotStatusView: View {
  init(viewModel: GithubCopilotStatusViewModel, isExpanded: Bool) {
    _viewModel = State(initialValue: viewModel)
    self.isExpanded = isExpanded
  }

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Text("GitHub Copilot")
        Spacer(minLength: 0)
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if isExpanded {
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

        if viewModel.isLSPServerInstalled {
          lspServerStatus
        } else {
          installLSPServerView
        }
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @State private var viewModel: GithubCopilotStatusViewModel

  @State private var isRequestingSigninInfo = false

  private let isExpanded: Bool

  private var installLSPServerView: some View {
    VStack(spacing: 12) {
      HoveredButton(
        action: {
          Task {
            try await viewModel.installLSPServer()
          }
        },
        onHoverColor: colorScheme.primaryActionHoveredBackground,
        backgroundColor: colorScheme.primaryActionBackground,
        cornerRadius: 6,
        isEnable: !viewModel.isInstallingLSPServer)
      {
        HStack {
          Image(systemName: "arrow.down.circle")
          if viewModel.isInstallingLSPServer {
            ThreeDotsLoadingAnimation(baseText: "Installing LSP Server")
          } else {
            Text("Install LSP Server")
          }
        }
        .foregroundColor(colorScheme.primaryActionForeground)
        .padding(4)
        .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder
  private var lspServerStatus: some View {
    // Status Section
    VStack(alignment: .leading, spacing: 10) {
      if case .loggedIn(user: let user) = viewModel.authStatus {
        HStack {
          Text("Signed in as \(user)")
        }

        Button(action: {
          Task {
            try await viewModel.signOut()
          }
        }) {
          HStack {
            Image(systemName: "rectangle.portrait.and.arrow.right")
            Text("Sign Out")
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      } else if let signInInfo = viewModel.signInInfo {
        HStack(spacing: 0) {
          Text(.init("Visit [\(signInInfo.verificationUri)](\(signInInfo.verificationUri)) and enter \(signInInfo.userCode)"))
            .textSelection(.enabled)

          // Refresh
          Spacer(minLength: 0)
          IconButton(
            action: {
              isRequestingSigninInfo = true
              do {
                try await viewModel.startSignIn()
              } catch { }
              isRequestingSigninInfo = false
            }, systemName: "arrow.trianglehead.2.clockwise.rotate.90",
            padding: 2)
            .frame(square: 20)
            .foregroundColor(colorScheme.primaryForeground)
        }

        HoveredButton(
          action: {
            Task {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(signInInfo.userCode, forType: .string)
              if let url = URL(string: signInInfo.verificationUri) {
                NSWorkspace.shared.open(url)
              }
              try await viewModel.confirmSignIn()
            }
          },
          onHoverColor: colorScheme.primaryActionHoveredBackground,
          backgroundColor: colorScheme.primaryActionBackground,
          cornerRadius: 6)
        {
          HStack {
            Image(systemName: "doc.on.doc")
            Text("Copy code and open link")
          }
          .foregroundColor(colorScheme.primaryActionForeground)
          .padding(4)
          .frame(maxWidth: .infinity)
        }
      } else if case .loggedOut = viewModel.authStatus {
        HoveredButton(
          action: {
            Task {
              isRequestingSigninInfo = true
              do {
                try await viewModel.startSignIn()
              } catch { }
              isRequestingSigninInfo = false
            }
          },
          onHoverColor: colorScheme.primaryActionHoveredBackground,
          backgroundColor: colorScheme.primaryActionBackground,
          cornerRadius: 6)
        {
          HStack {
            Image(systemName: "person.badge.key")
            if isRequestingSigninInfo {
              ThreeDotsLoadingAnimation(baseText: "Starting sign in")
            } else {
              Text("Sign In")
            }
          }
          .foregroundColor(colorScheme.primaryActionForeground)
          .padding(4)
          .frame(maxWidth: .infinity)
        }
      }
    }
  }

  private var statusColor: Color {
    switch viewModel.authStatus {
    case .loggedIn(user: _):
      .green
    case .loggedOut:
      .orange
    case .loggingIn:
      .orange
    }
  }
}
