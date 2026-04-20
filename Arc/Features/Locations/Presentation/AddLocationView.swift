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
                Section("Location") {
                    TextField("Name", text: $viewModel.name)
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
                    }
                    .disabled(viewModel.isResolvingCurrentLocation)

                    if viewModel.isResolvingCurrentLocation {
                        ProgressView()
                    }
                }

                Section("Search") {
                    HStack(spacing: 12) {
                        TextField("Search place or address", text: $viewModel.searchQuery)
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
                        .disabled(
                            viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            viewModel.isResolvingSearchResult
                        )
                    }

                    if viewModel.isResolvingSearchResult {
                        ProgressView("Searching...")
                    }

                    if !viewModel.suggestions.isEmpty {
                        ForEach(viewModel.suggestions) { suggestion in
                            Button {
                                Task {
                                    await viewModel.resolveSuggestion(suggestion)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Use Search to jump to a result, or pick a suggestion when one appears.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Map Pin") {
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
                    }

                    Text("Pan the map to move the pin. Search, GPS, and manual coordinates keep this pin in sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Coordinates") {
                    TextField("Latitude", text: $viewModel.latitudeText)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $viewModel.longitudeText)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.navigationTitle)
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
