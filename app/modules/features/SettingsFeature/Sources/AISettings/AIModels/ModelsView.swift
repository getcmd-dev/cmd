// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - ModelsView

struct ModelsView: View {
  /// - Parameters:
  ///   - availableModels: When provided, only those models are shown in the view. Otherwise all available models are shown.
  init(
    viewModel: LLMSettingsViewModel,
    provider: AIProvider? = nil)
  {
    self.viewModel = viewModel
    let availableModels: ObservableValue<[AIModel]> =
      if let provider {
        viewModel.modelsAvailable(for: provider).map({ $0.map(\.modelInfo) })
      } else {
        .init(viewModel.availableModels)
      }
    self.availableModels = availableModels
    _initialModelsOrder = .init(initialValue: availableModels.wrappedValue.sorted(by: viewModel.enabledModels))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)
          .frame(width: 16, height: 16)
        TextField("Search models...", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(8)
      .padding(.bottom, 20)

      // Models list
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(filteredModels, id: \.id) { model in
            ModelCard(
              model: model,
              provider: viewModel.provider(for: model),
              isActive: viewModel.isActive(for: model),
              availableProviders: viewModel.providersAvailable(for: model),
              reasoningSetting: viewModel.reasoningSetting(for: model))
          }
        }
        .padding(.bottom, 20)
      }
      .scrollIndicators(.hidden)
    }
//    .onReceive(modelsPublisher.receive(on: DispatchQueue.main), perform: { availableModels = $0 })
  }

  @Bindable private var availableModels: ObservableValue<[AIModel]>

  @State private var initialModelsOrder: [AIModelID: Int]
  @Bindable private var viewModel: LLMSettingsViewModel
  @State private var searchText = ""

//  @State private var availableModels: [AIModel]

//  private let modelsPublisher: AnyPublisher<[AIModel], Never>

  private var filteredModels: [AIModel] {
    availableModels
      .wrappedValue
      .filter {
        searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText)
      }
      .sorted(respecting: initialModelsOrder)
  }

}

// MARK: - ModelCard

struct ModelCard: View {
  init(
    model: AIModel,
    provider: Binding<AIProvider>,
    isActive: Binding<Bool>,
    availableProviders: [AIProvider],
    reasoningSetting: Binding<LLMReasoningSetting>?)
  {
    self.model = model
    self.availableProviders = availableProviders
    self.reasoningSetting = reasoningSetting
    _provider = provider
    _isActive = isActive
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack(alignment: .center) {
        Text(model.name)
          .font(.title3)
          .fontWeight(.semibold)

        if let documentationURL = model.documentationURL {
          IconButton(
            action: {
              NSWorkspace.shared.open(documentationURL)
            },
            systemName: "arrow.up.right",
            onHoverColor: colorScheme.secondarySystemBackground,
            padding: 6)
            .frame(width: 20, height: 20)
        }

        Spacer()

        if !otherProviderOptions.isEmpty {
          HoveredButton(
            action: {
              isSelectingProvider.toggle()
            },
            onHoverColor: colorScheme.secondarySystemBackground,
            backgroundColor: isSelectingProvider ? colorScheme.secondarySystemBackground : .clear,
            padding: 6,
            cornerRadius: 6)
          {
            Text(provider.name)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        } else {
          Text(provider.name)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }

      if isSelectingProvider {
        HStack {
          Spacer(minLength: 0)
          WrappingHStack(horizontalSpacing: 4, alignment: .trailing) {
            ForEach(otherProviderOptions, id: \.id) { otherProvider in
              HoveredButton(
                action: {
                  isSelectingProvider = false
                  provider = otherProvider
                },
                onHoverColor: colorScheme.secondarySystemBackground,
                padding: 6,
                cornerRadius: 6)
              {
                Text(otherProvider.name)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }

      if let description = model.description {
        Text(description)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }

      if let reasoningSetting, isActive {
        HStack {
          Text("Reasoning:")
            .font(.headline)
            .fontWeight(.medium)
          Spacer(minLength: 0)
          Toggle("", isOn: reasoningSetting.isEnabled)
            .toggleStyle(.switch)
        }
        .padding(.top, 8)
      }

      if let pricing = model.defaultPricing {
        HStack {
          Text("Pricing:")
            .font(.headline)
            .fontWeight(.medium)
          Text("\(displayPrice(pricing.input)) / \(displayPrice(pricing.output))")
            .fontWeight(.medium)

          Spacer()

          Toggle("", isOn: $isActive)
            .toggleStyle(.switch)
        }
        .padding(.top, 8)
      }

      if provider.externalAgent != nil {
        Text("\(model.name) is an external agent")
      }
    }
    .padding(16)
    .background(Color(NSColor.controlBackgroundColor))
    .with(cornerRadius: 6, borderColor: Color.gray.opacity(0.2))
  }

  @Binding private var provider: AIProvider
  @Binding private var isActive: Bool
  @Environment(\.colorScheme) private var colorScheme
  @State private var isSelectingProvider = false

  private let reasoningSetting: Binding<LLMReasoningSetting>?

  private let model: AIModel
  private let availableProviders: [AIProvider]

  private var otherProviderOptions: [AIProvider] {
    availableProviders.filter { $0 != provider }
  }

  private func displayPrice(_ price: Double) -> String {
    if abs(Double(Int(price)) - price) < 0.00001 {
      return "$\(Int(price))"
    }
    return "$\(String(format: "%.2f", price))"
  }

}

extension [AIModel] {
  func sorted(by enabled: [AIModelID]) -> [AIModelID: Int] {
    sorted(by: { a, b in
      switch (enabled.contains(a.id), enabled.contains(b.id)) {
      case (true, false):
        true
      case (false, true):
        false
      default:
        a.rankForProgramming < b.rankForProgramming
      }
    })
    .reduce(into: [:], { acc, model in
      acc[model.id] = acc.count
    })
  }

  func sorted(respecting initialOrder: [AIModelID: Int]) -> [AIModel] {
    sorted(by: { a, b in
      (initialOrder[a.id] ?? Int.max) < (initialOrder[b.id] ?? Int.max)
    })
  }
}
