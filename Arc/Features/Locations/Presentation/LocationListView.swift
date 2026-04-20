import SwiftData
import SwiftUI

struct LocationListView: View {
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShootLocation.createdAt, order: .reverse) private var locations: [ShootLocation]
    @State private var isPresentingAddLocation = false

    private var heroBadges: [ArcHeroBadge] {
        [
            ArcHeroBadge(label: "\(locations.count) saved", systemImage: "bookmark")
        ]
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "mountain.2.fill",
                    title: "Scout Locations",
                    subtitle: "Save a place, then move into planning when it feels right.",
                    badges: heroBadges
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if locations.isEmpty {
                Section {
                    EmptyLocationsCard {
                        isPresentingAddLocation = true
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section("Saved Locations") {
                    ForEach(locations) { location in
                        NavigationLink {
                            LocationDetailView(
                                location: location,
                                aiService: aiService,
                                locationEditorServices: locationEditorServices
                            )
                        } label: {
                            LocationSummaryCard(location: location)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: deleteLocations)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingAddLocation = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add location")
            }
        }
        .sheet(isPresented: $isPresentingAddLocation) {
            LocationEditorView(services: locationEditorServices) { draft in
                modelContext.insert(
                    ShootLocation(
                        name: draft.name,
                        latitude: draft.coordinate.latitude,
                        longitude: draft.coordinate.longitude
                    )
                )
            }
        }
    }

    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(locations[index])
        }
    }
}

private struct EmptyLocationsCard: View {
    let addAction: () -> Void

    var body: some View {
        ArcFeatureCard {
            ArcFeatureTitle(
                systemImage: "map",
                title: "Add your first location",
                subtitle: "Start with one saved place."
            )

            Text("Use GPS, search, or the map pin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add First Location", action: addAction)
                .frame(maxWidth: .infinity)
                .buttonStyle(.glassProminent)
        }
    }
}

private struct LocationSummaryCard: View {
    let location: ShootLocation

    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "mappin.and.ellipse",
                title: location.name,
                subtitle: location.createdAt.formatted(date: .abbreviated, time: .omitted)
            )

            Label(
                "\(location.latitude.formatted(.number.precision(.fractionLength(4)))), \(location.longitude.formatted(.number.precision(.fractionLength(4))))",
                systemImage: "location.north.line"
            )
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}
