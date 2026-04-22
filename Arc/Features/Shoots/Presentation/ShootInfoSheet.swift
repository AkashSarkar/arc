import MapKit
import SwiftUI

struct ShootInfoSheet: View {
    let location: ShootLocation
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingEditLocation = false
    @State private var selectedSection: ShootInfoSection = .location

    private var plan: ShootPlan? {
        location.plan
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
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
                        title: "Shoot Info",
                        summary: location.name
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
                LocationEditorView(location: location, services: locationEditorServices) { draft in
                    location.name = draft.name
                    location.latitude = draft.coordinate.latitude
                    location.longitude = draft.coordinate.longitude
                }
            }
            .task(id: location.enrichmentJSON) {
                cacheStatus = referenceImageCache.cacheStatus(for: location)
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
                    subtitle: "\(location.latitude.formatted(.number.precision(.fractionLength(5)))), \(location.longitude.formatted(.number.precision(.fractionLength(5))))",
                    accent: ArcPalette.tint
                )

                Map(initialPosition: .region(mapRegion)) {
                    Marker(location.name, coordinate: coordinate)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

                Button {
                    isPresentingEditLocation = true
                } label: {
                    Label("Edit Location", systemImage: "slider.horizontal.3")
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
                LocationContextView(location: location, locationEnricher: locationEnricher)
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

                if let plan {
                    HStack(spacing: 8) {
                        ArcStatusPill(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                        ArcStatusPill(plan.shootWindowSummary, systemImage: "calendar.badge.clock", tint: ArcPalette.glowPrimary)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var contextSubtitle: String {
        if let lastEnrichedAt = location.lastEnrichedAt,
           !location.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Tap to refresh or inspect."
        }

        return "No cached context yet. Tap to fetch landmarks, weather, and sun/moon timing."
    }

    private var referenceSubtitle: String {
        guard cacheStatus.totalImages > 0 else {
            return "No offline reference images cached for this shoot."
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
