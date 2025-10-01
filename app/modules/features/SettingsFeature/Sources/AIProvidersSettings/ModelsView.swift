// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Dependencies
import DLS
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - ModelsView

struct ModelsView: View {
  init(
    viewModel: LLMSettingsViewModel,
    availableModels: [LLMModelInfo]? = nil)
//    availableModels: [LLMModelInfo],
//    availableProviders: [LLMProvider],
//    providerForModels: Binding<[LLMModelInfo: LLMProvider]>,
  ////    inactiveModels: Binding<[LLMModelInfo]>,
//    reasoningModels: Binding<[LLMModelInfo: LLMReasoningSetting]>)
  {
    self.viewModel = viewModel
    self.availableModels = availableModels ?? viewModel.availableModels
    _initialModelsOrder = .init(initialValue: self.availableModels.sorted(by: viewModel.enabledModels))
//    self.availableModels = availableModels
//    self.availableProviders = availableProviders
//    _providerForModels = providerForModels
    ////    _inactiveModels = inactiveModels
//    _reasoningModels = reasoningModels
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
  }

  @State private var initialModelsOrder: [ModelInfoId: Int]
  @Bindable private var viewModel: LLMSettingsViewModel
  ///  @Binding private var providerForModels: [LLMModelInfo: LLMProvider]
  ///  @Binding private var inactiveModels: [LLMModelInfo]
  ///  @Binding private var reasoningModels: [LLMModelInfo: LLMReasoningSetting]
  @State private var searchText = ""

  private let availableModels: [LLMModelInfo]

  @Dependency(\.llmService) private var llmService

//  private let availableModels: [LLMModelInfo]
//  private let availableProviders: [LLMProvider]

  private var filteredModels: [LLMModelInfo] {
    availableModels
      .filter {
        searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText)
      }
      .sorted(respecting: initialModelsOrder)
  }

}

// MARK: - ModelCard

struct ModelCard: View {
  init(
    model: LLMModelInfo,
    provider: Binding<LLMProvider>,
    isActive: Binding<Bool>,
    availableProviders: [LLMProvider],
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

  @Binding private var provider: LLMProvider
  @Binding private var isActive: Bool
  @Environment(\.colorScheme) private var colorScheme
  @State private var isSelectingProvider = false

  private let reasoningSetting: Binding<LLMReasoningSetting>?

  private let model: LLMModelInfo
  private let availableProviders: [LLMProvider]

  private var otherProviderOptions: [LLMProvider] {
    availableProviders.filter { $0 != provider }
  }

  private func displayPrice(_ price: Double) -> String {
    if abs(Double(Int(price)) - price) < 0.00001 {
      return "$\(Int(price))"
    }
    return "$\(String(format: "%.2f", price))"
  }

}

extension [LLMModelInfo] {
  func sorted(by enabled: [ModelInfoId]) -> [ModelInfoId: Int] {
    sorted(by: { a, b in
      switch (enabled.contains(a.id), enabled.contains(b.id)) {
      case (true, false):
        true
      case (false, true):
        false
      default:
        true
      }
    })
    .reduce(into: [:], { acc, model in
      acc[model.id] = acc.count
    })
  }

  func sorted(respecting initialOrder: [ModelInfoId: Int]) -> [LLMModelInfo] {
    sorted(by: { a, b in
      (initialOrder[a.id] ?? Int.max) < (initialOrder[b.id] ?? Int.max)
    })
  }
}
