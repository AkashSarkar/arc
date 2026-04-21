import MapKit
import SwiftUI

struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LocationEditorViewModel

    private let onSave: (LocationDraftValue) throws -> Void

    init(
        location: ShootLocation? = nil,
        services: LocationEditorServiceFactory,
        onSave: @escaping (LocationDraftValue) throws -> Void
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
        NavigationStack {
            ShootSpotPickerView(
                viewModel: viewModel,
                systemImage: viewModel.isEditing ? "slider.horizontal.3" : "location.viewfinder",
                title: viewModel.isEditing ? "Edit Shoot Spot" : "Choose Shoot Spot",
                subtitle: "Search, use GPS, or drag the map until the pin sits on the exact place you will shoot.",
                badges: [
                    ArcHeroBadge(label: "GPS", systemImage: "location.fill"),
                    ArcHeroBadge(label: "Search", systemImage: "magnifyingglass"),
                    ArcHeroBadge(label: "Pin", systemImage: "mappin.circle")
                ],
                primaryButtonTitle: viewModel.saveButtonTitle,
                primarySystemImage: viewModel.isEditing ? "checkmark" : "arrow.right",
                primaryAction: saveLocation
            )
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveLocation() {
        guard let draft = viewModel.validatedDraft() else {
            return
        }

        do {
            try onSave(draft)
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

struct LocationMapPicker: View {
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
        .frame(minHeight: 380)
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
