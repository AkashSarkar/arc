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
            VStack(alignment: .leading, spacing: 16) {
                ArcHeroHeader(
                    systemImage: systemImage,
                    title: title,
                    subtitle: subtitle,
                    badges: badges
                )

                searchCard
                mapCard
                confirmationCard
            }
            .padding(20)
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

    private var searchCard: some View {
        ArcFeatureCard(accent: ArcPalette.glowSecondary) {
            ArcFeatureTitle(
                systemImage: "magnifyingglass",
                title: "Find the spot",
                subtitle: "Search by place name, use GPS, or drag the map pin."
            )

            HStack(alignment: .center, spacing: 10) {
                editorTextField("Search place or address", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.searchUsingQuery()
                        }
                    }

                Button {
                    Task {
                        await viewModel.useCurrentLocation()
                    }
                } label: {
                    Image(systemName: viewModel.isResolvingCurrentLocation ? "location.circle" : "location.fill")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isResolvingCurrentLocation)
                .accessibilityLabel("Use current location")

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

            if viewModel.isResolvingCurrentLocation {
                ProgressView("Finding current location...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.isResolvingSearchResult {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !viewModel.suggestions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(viewModel.suggestions) { suggestion in
                        Button {
                            Task {
                                await viewModel.resolveSuggestion(suggestion)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                ArcMiniIconBadge(systemImage: "mappin.and.ellipse", tint: ArcPalette.glowSecondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
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
                            .padding(14)
                            .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var mapCard: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "map",
                title: "Set the pin",
                subtitle: "Move the map until the pin sits on the exact shooting position.",
                accent: ArcPalette.glowPrimary
            )

            ZStack(alignment: .topLeading) {
                LocationMapPicker(
                    selectedCoordinate: viewModel.selectedCoordinate,
                    mapFocusCoordinate: viewModel.mapFocusCoordinate,
                    mapFocusVersion: viewModel.mapFocusVersion,
                    onMapSelectionChanged: { coordinate in
                        viewModel.updateMapPin(to: coordinate)
                    }
                )

                if viewModel.isReverseGeocoding {
                    Label("Updating name", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(12)
                }
            }
        }
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
