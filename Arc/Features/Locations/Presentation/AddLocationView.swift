import MapKit
import SwiftUI

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LocationEditorViewModel

    private let onSave: (LocationDraftValue) -> Void

    init(
        location: ShootLocation? = nil,
        services: LocationEditorServiceFactory,
        onSave: @escaping (LocationDraftValue) -> Void
    ) {
        _viewModel = State(
            initialValue: LocationEditorViewModel(
                location: location,
                currentLocationService: services.makeCurrentLocationService(),
                searchService: services.makeSearchService(),
                reverseGeocodingService: services.makeReverseGeocodingService()
            )
        )
        self.onSave = onSave
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    ArcHeroHeader(
                        systemImage: viewModel.isEditing ? "slider.horizontal.3" : "location.viewfinder",
                        title: viewModel.navigationTitle,
                        subtitle: "Start from your current GPS, search for a place, or nudge the map until the pin matches the exact shoot spot.",
                        badges: [
                            ArcHeroBadge(label: "Current GPS", systemImage: "location.fill"),
                            ArcHeroBadge(label: "Map pin", systemImage: "mappin.circle"),
                            ArcHeroBadge(label: "Search", systemImage: "magnifyingglass")
                        ]
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    ArcFeatureCard {
                        ArcFeatureTitle(
                            systemImage: "text.cursor",
                            title: "Location Name",
                            subtitle: "The title can come from GPS, search, or the pin, then be refined by hand."
                        )

                        editorTextField("Name", text: $viewModel.name)
                            .textInputAutocapitalization(.words)

                        Button {
                            Task {
                                await viewModel.useCurrentLocation()
                            }
                        } label: {
                            Label(
                                viewModel.isResolvingCurrentLocation ? "Resolving current GPS..." : "Use Current GPS",
                                systemImage: "location.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.isResolvingCurrentLocation)

                        if viewModel.isResolvingCurrentLocation {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                        ArcFeatureTitle(
                            systemImage: "magnifyingglass",
                            title: "Search",
                            subtitle: "Look up a place or address, then jump the pin directly to that result."
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

                            Button("Search") {
                                Task {
                                    await viewModel.searchUsingQuery()
                                }
                            }
                            .buttonStyle(.glass)
                            .disabled(
                                viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                viewModel.isResolvingSearchResult
                            )
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
                                            ArcMiniIconBadge(systemImage: "mappin.and.ellipse")

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
                                        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Use Search to jump to a result, or pick a suggestion when one appears.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                        ArcFeatureTitle(
                            systemImage: "map",
                            title: "Map Pin",
                            subtitle: "Pan the map until the centered pin lands on the exact spot you want to save."
                        )

                        LocationMapPicker(
                            selectedCoordinate: viewModel.selectedCoordinate,
                            mapFocusCoordinate: viewModel.mapFocusCoordinate,
                            mapFocusVersion: viewModel.mapFocusVersion,
                            onMapSelectionChanged: { coordinate in
                                viewModel.updateMapPin(to: coordinate)
                            }
                        )

                        Text(viewModel.coordinateSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if viewModel.isReverseGeocoding {
                            ProgressView("Updating place name...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Search, GPS, and manual coordinates all stay synced with this pin.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    ArcFeatureCard {
                        ArcFeatureTitle(
                            systemImage: "number",
                            title: "Manual Coordinates",
                            subtitle: "Use direct latitude and longitude entry when you need exact numeric control."
                        )

                        editorTextField("Latitude", text: $viewModel.latitudeText)
                            .keyboardType(.decimalPad)

                        editorTextField("Longitude", text: $viewModel.longitudeText)
                            .keyboardType(.decimalPad)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ArcFeatureCard(accent: .red) {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadDefaultLocationIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.saveButtonTitle) {
                        saveLocation()
                    }
                }
            }
        }
    }

    private func saveLocation() {
        guard let draft = viewModel.validatedDraft() else {
            return
        }

        onSave(draft)
        dismiss()
    }

    private func editorTextField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
            }
    }
}

private struct LocationMapPicker: View {
    let selectedCoordinate: LocationCoordinate?
    let mapFocusCoordinate: LocationCoordinate?
    let mapFocusVersion: Int
    let onMapSelectionChanged: (LocationCoordinate) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var hasIgnoredInitialCameraEvent = false

    init(
        selectedCoordinate: LocationCoordinate?,
        mapFocusCoordinate: LocationCoordinate?,
        mapFocusVersion: Int,
        onMapSelectionChanged: @escaping (LocationCoordinate) -> Void
    ) {
        self.selectedCoordinate = selectedCoordinate
        self.mapFocusCoordinate = mapFocusCoordinate
        self.mapFocusVersion = mapFocusVersion
        self.onMapSelectionChanged = onMapSelectionChanged

        if let selectedCoordinate {
            _cameraPosition = State(initialValue: .region(Self.region(for: selectedCoordinate)))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }

    var body: some View {
        Map(position: $cameraPosition) {
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .frame(minHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 10)
        .overlay(alignment: .center) {
            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.red)
                    .shadow(radius: 4, y: 1)
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
            .offset(y: -18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            if !hasIgnoredInitialCameraEvent, selectedCoordinate == nil, mapFocusVersion == 0 {
                hasIgnoredInitialCameraEvent = true
                return
            }

            hasIgnoredInitialCameraEvent = true
            onMapSelectionChanged(LocationCoordinate(context.region.center))
        }
        .onChange(of: mapFocusVersion) { _, _ in
            guard let mapFocusCoordinate else {
                return
            }

            cameraPosition = .region(Self.region(for: mapFocusCoordinate))
        }
    }

    private static func region(for coordinate: LocationCoordinate) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    }
}
