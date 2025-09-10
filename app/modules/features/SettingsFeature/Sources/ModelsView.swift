// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import DLS
import LLMFoundation
import SettingsServiceInterface
import SwiftUI

// MARK: - ModelsView

struct ModelsView: View {
  init(
    availableModels: [LLMModel],
    availableProviders: [LLMProvider],
    providerForModels: Binding<[LLMModel: LLMProvider]>,
    inactiveModels: Binding<[LLMModel]>,
    reasoningModels: Binding<[LLMModel: LLMReasoningSetting]>)
  {
    self.availableModels = availableModels
    self.availableProviders = availableProviders
    _providerForModels = providerForModels
    _inactiveModels = inactiveModels
    _reasoningModels = reasoningModels
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
              provider: provider(for: model),
              isActive: isActive(for: model),
              availableProviders: availableProviders.filter { $0.supportedModels.contains(model) },
              reasoningSetting: reasoningSetting(for: model))
          }
        }
        .padding(.bottom, 20)
      }
      .scrollIndicators(.hidden)
    }
  }

  @Binding private var providerForModels: [LLMModel: LLMProvider]
  @Binding private var inactiveModels: [LLMModel]
  @Binding private var reasoningModels: [LLMModel: LLMReasoningSetting]
  @State private var searchText = ""

  private let availableModels: [LLMModel]
  private let availableProviders: [LLMProvider]

  private var filteredModels: [LLMModel] {
    searchText.isEmpty
      ? availableModels
      : availableModels.filter {
        $0.name.localizedCaseInsensitiveContains(searchText)
      }
  }

  private func provider(for model: LLMModel) -> Binding<LLMProvider> {
    .init(get: {
      providerForModels[model] ?? LLMProvider.openAI
    }, set: { provider in
      providerForModels[model] = provider
    })
  }

  private func isActive(for model: LLMModel) -> Binding<Bool> {
    .init(get: { !inactiveModels.contains(model) }, set: { isActive in
      if isActive {
        inactiveModels.removeAll { $0 == model }
      } else {
        if !inactiveModels.contains(model) {
          inactiveModels.append(model)
        }
      }
    })
  }

  private func reasoningSetting(for model: LLMModel) -> Binding<LLMReasoningSetting>? {
    guard let reasoning = reasoningModels[model] else { return nil }
    return .init(get: { reasoning }, set: { reasoningModels[model] = $0 })
  }

}

// MARK: - ModelCard

private struct ModelCard: View {
  init(
    model: LLMModel,
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

      if let pricing = provider.price(for: model) ?? model.defaultPricing {
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

  private let model: LLMModel
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
