import MapKit
import SwiftUI

struct ShootInfoSheet: View {
    let stop: Stop
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingEditLocation = false
    @State private var selectedSection: ShootInfoSection = .location

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = stop.latitude, let longitude = stop.longitude else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var mapRegion: MKCoordinateRegion? {
        guard let coordinate else {
            return nil
        }

        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ArcCompactHeroHeader(
                        systemImage: "info.circle.fill",
                        title: "Stop Info",
                        summary: stop.name
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Picker("Info section", selection: $selectedSection) {
                        ForEach(ShootInfoSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                currentSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditLocation) {
                LocationEditorView(location: stop, services: locationEditorServices) { draft in
                    stop.name = draft.name
                    stop.placeName = draft.name
                    stop.latitude = draft.coordinate.latitude
                    stop.longitude = draft.coordinate.longitude
                }
            }
            .task(id: stop.enrichmentJSON) {
                cacheStatus = referenceImageCache.cacheStatus(for: stop)
            }
        }
    }

    @ViewBuilder
    private var currentSection: some View {
        switch selectedSection {
        case .location:
            locationSection
        case .context:
            contextSection
        case .references:
            referencesSection
        }
    }

    private var locationSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "map",
                    title: "Location",
                    subtitle: stop.coordinateSummary,
                    accent: ArcPalette.tint
                )

                if let mapRegion, let coordinate {
                    Map(initialPosition: .region(mapRegion)) {
                        Marker(stop.name, coordinate: coordinate)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
                }

                Button {
                    isPresentingEditLocation = true
                } label: {
                    Label(stop.hasResolvedCoordinate ? "Edit Location" : "Set Location", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var contextSection: some View {
        Section {
            NavigationLink {
                LocationContextView(location: stop, locationEnricher: locationEnricher)
            } label: {
                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "map.circle.fill",
                        title: "Context",
                        subtitle: contextSubtitle,
                        accent: ArcPalette.glowSecondary
                    )
                }
            }
            .disabled(!stop.hasResolvedCoordinate)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var referencesSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                ArcFeatureTitle(
                    systemImage: "arrow.down.circle",
                    title: "References",
                    subtitle: referenceSubtitle,
                    accent: ArcPalette.glowPrimary
                )

                if let trip = stop.day?.trip {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ArcStatusPill(trip.outputIntent.title, systemImage: "square.stack.3d.up")
                            ArcStatusPill(trip.captureMedium.title, systemImage: "camera", tint: ArcPalette.tint)
                            ArcStatusPill(trip.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.glowPrimary)
                            ArcStatusPill(trip.stylePreset.title, systemImage: "camera.filters", tint: ArcPalette.glowSecondary)
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var contextSubtitle: String {
        guard stop.hasResolvedCoordinate else {
            return "Set a location before fetching landmarks, weather, and sun timing."
        }

        if let lastEnrichedAt = stop.lastEnrichedAt,
           !stop.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Tap to refresh or inspect."
        }

        return "No cached context yet. Tap to fetch landmarks, weather, and sun/moon timing."
    }

    private var referenceSubtitle: String {
        guard cacheStatus.totalImages > 0 else {
            return "No offline reference images cached for this stop."
        }

        return "\(cacheStatus.cachedImages) of \(cacheStatus.totalImages) cached for offline use."
    }
}

private enum ShootInfoSection: String, CaseIterable, Identifiable {
    case location
    case context
    case references

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .context:
            return "Context"
        case .references:
            return "Refs"
        }
    }
}
