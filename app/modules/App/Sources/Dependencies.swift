// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventService
import AppEventServiceInterface
import AppKit
import AppUpdateService
import AppUpdateServiceInterface
import ChatCompletionService
import ChatCompletionServiceInterface
import ChatService
import ChatServiceInterface
import CheckpointService
import CheckpointServiceInterface
import Combine
import Dependencies
import FileSuggestionService
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import HighlighterServiceInterface
import LLMService
import LLMServiceInterface
import LocalServerService
import LocalServerServiceInterface
import LoggingServiceInterface
import PermissionsService
import PermissionsServiceInterface
import SettingsService
import SettingsServiceInterface
import ShellService
import ShellServiceInterface
import ToolFoundation
import XcodeControllerService
import XcodeControllerServiceInterface
import XcodeObserverService
import XcodeObserverServiceInterface

// MARK: - AppEventHandlerRegistryDependencyKey + DependencyKey

extension AppEventHandlerRegistryDependencyKey: DependencyKey {
  public static var liveValue: AppEventHandlerRegistry { AppScope.shared.appEventHandlerRegistry }
}

// MARK: - AppsActivationStateDependencyKey + DependencyKey

extension AppsActivationStateDependencyKey: DependencyKey {
  public static var liveValue: AnyPublisher<AppsActivationState, Never> {
    AppScope.shared.appsActivationState
  }
}

// MARK: - AppUpdateServiceDependencyKey + DependencyKey

extension AppUpdateServiceDependencyKey: DependencyKey {
  public static var liveValue: AppUpdateService {
    AppScope.shared.appUpdateService
  }
}

// MARK: - ChatHistoryServiceDependencyKey + DependencyKey

extension ChatHistoryServiceDependencyKey: DependencyKey {
  public static var liveValue: ChatHistoryService { AppScope.shared.chatHistoryService }
}

// MARK: - ChatContextRegistryServiceDependencyKey + DependencyKey

extension ChatContextRegistryServiceDependencyKey: DependencyKey {
  public static var liveValue: ChatContextRegistryService { AppScope.shared.chatContextRegistry }
}

// MARK: - ChatCompletionServiceDependencyKey + DependencyKey

extension ChatCompletionServiceDependencyKey: DependencyKey {
  public static var liveValue: ChatCompletionService { AppScope.shared.chatCompletionService }
}

// MARK: - CheckpointServiceDependencyKey + DependencyKey

extension CheckpointServiceDependencyKey: DependencyKey {
  public static var liveValue: CheckpointService { AppScope.shared.checkpointService }
}

// MARK: - FileManagerDependencyKey + DependencyKey

extension FileManagerDependencyKey: DependencyKey {
  public static var liveValue: FileManagerI {
    FileManager.default
  }
}

// MARK: - FileSuggestionServiceDependencyKey + DependencyKey

extension FileSuggestionServiceDependencyKey: DependencyKey {
  public static var liveValue: FileSuggestionService { AppScope.shared.fileSuggestionService }
}

// MARK: - HighlighterServiceDependencyKey + DependencyKey

extension HighlighterServiceDependencyKey: DependencyKey {
  public static var liveValue: Highlight { AppScope.shared.highlighter }
}

// MARK: - LLMServiceDependencyKey + DependencyKey

extension LLMServiceDependencyKey: DependencyKey {
  public static var liveValue: LLMService { AppScope.shared.llmService }
}

// MARK: - PermissionsServiceDependencyKey + DependencyKey

extension PermissionsServiceDependencyKey: DependencyKey {
  public static var liveValue: PermissionsService { AppScope.shared.permissionsService }
}

// MARK: - LocalServerDependencyKey + DependencyKey

extension LocalServerDependencyKey: DependencyKey {
  public static var liveValue: LocalServer { AppScope.shared.localServer }
}

// MARK: - SettingsServiceDependencyKey + DependencyKey

extension SettingsServiceDependencyKey: DependencyKey {
  public static var liveValue: SettingsService { AppScope.shared.settingsService }
}

// MARK: - SharedUserDefaultsDependencyKey + DependencyKey

extension SharedUserDefaultsDependencyKey: DependencyKey {
  public static var liveValue: any UserDefaultsI { AppScope.shared.sharedUserDefaults }
}

// MARK: - ShellServiceDependencyKey + DependencyKey

extension ShellServiceDependencyKey: DependencyKey {
  public static var liveValue: ShellService { AppScope.shared.shellService }
}

// MARK: - ToolsPluginDependencyKey + DependencyKey

extension ToolsPluginDependencyKey: DependencyKey {
  public static var liveValue: ToolsPlugin { AppScope.shared.toolsPlugin }
}

// MARK: - XcodeControllerDependencyKey + DependencyKey

extension XcodeControllerDependencyKey: DependencyKey {
  public static var liveValue: XcodeController { AppScope.shared.xcodeController }
}

// MARK: - XcodeObserverDependencyKey + DependencyKey

extension XcodeObserverDependencyKey: DependencyKey {
  public static var liveValue: XcodeObserver { AppScope.shared.xcodeObserver }
}

// MARK: - AppScope + AppEventHandlerRegistryProviding

extension AppScope: AppEventHandlerRegistryProviding { }

// MARK: - AppScope + AppsActivationStateProviding

extension AppScope: AppsActivationStateProviding { }

// MARK: - AppScope + AppUpdateServiceProviding

extension AppScope: AppUpdateServiceProviding { }

// MARK: - AppScope + ChatHistoryServiceProviding

extension AppScope: ChatHistoryServiceProviding { }

// MARK: - AppScope + ChatContextRegistryServiceProviding

extension AppScope: ChatContextRegistryServiceProviding { }

// MARK: - AppScope + ChatCompletionServiceProviding

extension AppScope: ChatCompletionServiceProviding { }

// MARK: - AppScope + CheckpointServiceProviding

extension AppScope: CheckpointServiceProviding { }

// MARK: - AppScope + FileManagerProviding

extension AppScope: FileManagerProviding { }

// MARK: - AppScope + HighlighterServiceProviding

extension AppScope: HighlighterServiceProviding { }

// MARK: - AppScope + IsHostAppActiveProviding

extension AppScope: IsHostAppActiveProviding {
  var isHostAppActive: AnyPublisher<Bool, Never> {
    sharedDependencies!.isAppActive
  }
}

// MARK: - AppScope + LLMServiceProviding

extension AppScope: LLMServiceProviding { }

// MARK: - AppScope + PermissionsServiceProviding

extension AppScope: PermissionsServiceProviding { }

// MARK: - AppScope + LocalServerProviding

extension AppScope: LocalServerProviding { }

// MARK: - AppScope + SettingsServiceProviding

extension AppScope: SettingsServiceProviding { }

// MARK: - AppScope + ShellServiceProviding

extension AppScope: ShellServiceProviding { }

// MARK: - AppScope + ToolsPluginProviding

extension AppScope: ToolsPluginProviding { }

// MARK: - AppScope + UserDefaultsProviding

extension AppScope: UserDefaultsProviding {
  var sharedUserDefaults: any UserDefaultsI {
    shared {
      do {
        guard let userDefaults = try UserDefaults.shared(bundle: Bundle(for: AppScope.self)) else {
          return Foundation.UserDefaults.standard
        }
        return userDefaults
      } catch {
        return Foundation.UserDefaults.standard
      }
    }
  }
}

// MARK: - AppScope + XcodeControllerProviding

extension AppScope: XcodeControllerProviding { }

// MARK: - AppScope + XcodeObserverProviding

extension AppScope: XcodeObserverProviding { }
