import SwiftUI

struct ShootSpotPickerView: View {
    @Bindable var viewModel: LocationEditorViewModel

    let systemImage: String
    let title: String
    let subtitle: String
    let badges: [ArcHeroBadge]
    let primaryButtonTitle: String
    let primarySystemImage: String
    let primaryAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                compactHeroHeader

                mapCard
                confirmationCard
            }
            .padding(16)
            .padding(.bottom, 112)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ArcSceneBackground())
        .safeAreaInset(edge: .bottom) {
            confirmationBar
        }
        .task {
            await viewModel.loadDefaultLocationIfNeeded()
        }
    }

    private var compactHeroHeader: some View {
        HStack(spacing: 12) {
            ArcMiniIconBadge(systemImage: systemImage, tint: ArcPalette.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                if !compactHeroSummary.isEmpty {
                    Text(compactHeroSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ArcPalette.surfaceFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }

    private var compactHeroSummary: String {
        badges.map(\.label).joined(separator: " • ")
    }

    private var mapCard: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "magnifyingglass",
                title: "Find the spot",
                subtitle: nil,
                accent: ArcPalette.glowPrimary
            )

            ZStack(alignment: .top) {
                LocationMapPicker(
                    selectedCoordinate: viewModel.selectedCoordinate,
                    mapFocusCoordinate: viewModel.mapFocusCoordinate,
                    mapFocusVersion: viewModel.mapFocusVersion,
                    onMapSelectionChanged: { coordinate in
                        viewModel.updateMapPin(to: coordinate)
                    }
                )

                VStack(spacing: 10) {
                    mapSearchPanel

                    if let statusText = mapStatusText {
                        Label(statusText, systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                    }

                    if !viewModel.suggestions.isEmpty {
                        mapSuggestionsPanel
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
    }

    private var mapSearchPanel: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("Search place or address", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                }
                .onSubmit {
                    Task {
                        await viewModel.searchUsingQuery()
                    }
                }

            Button {
                Task {
                    await viewModel.searchUsingQuery()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .disabled(
                viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                viewModel.isResolvingSearchResult
            )
            .accessibilityLabel("Search")
        }
    }

    private var mapSuggestionsPanel: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.suggestions.prefix(4))) { suggestion in
                Button {
                    Task {
                        await viewModel.resolveSuggestion(suggestion)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ArcPalette.glowSecondary)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mapStatusText: String? {
        if viewModel.isResolvingCurrentLocation {
            return "Finding current location"
        }

        if viewModel.isResolvingSearchResult {
            return "Searching"
        }

        if viewModel.isReverseGeocoding {
            return "Updating name"
        }

        return nil
    }

    private var confirmationCard: some View {
        ArcFeatureCard(accent: ArcPalette.tint) {
            ArcFeatureTitle(
                systemImage: "checkmark.circle",
                title: "Confirm spot",
                subtitle: "Rename the spot if the suggested name is not useful in the field.",
                accent: ArcPalette.tint
            )

            editorTextField("Shoot spot name", text: $viewModel.name)
                .textInputAutocapitalization(.words)

            Label(viewModel.coordinateSummary, systemImage: "location.north.line")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                }

            DisclosureGroup {
                VStack(spacing: 10) {
                    editorTextField("Latitude", text: $viewModel.latitudeText)
                        .keyboardType(.decimalPad)

                    editorTextField("Longitude", text: $viewModel.longitudeText)
                        .keyboardType(.decimalPad)
                }
                .padding(.top, 8)
            } label: {
                Label("Coordinates", systemImage: "number")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var confirmationBar: some View {
        VStack(spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.selectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(viewModel.coordinateSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    primaryAction()
                } label: {
                    Label(primaryButtonTitle, systemImage: primarySystemImage)
                        .lineLimit(1)
                }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.canConfirmSelection)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private func editorTextField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
            }
    }
}
