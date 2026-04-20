import SwiftData
import SwiftUI

struct LocationListView: View {
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShootLocation.createdAt, order: .reverse) private var locations: [ShootLocation]
    @State private var isPresentingAddLocation = false

    var body: some View {
        List {
            if locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add your first shoot location to start planning.")
                )
            } else {
                ForEach(locations) { location in
                    NavigationLink {
                        LocationDetailView(
                            location: location,
                            aiService: aiService,
                            locationEditorServices: locationEditorServices
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name)
                                .font(.headline)
                            Text("\(location.latitude.formatted(.number.precision(.fractionLength(4)))), \(location.longitude.formatted(.number.precision(.fractionLength(4))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteLocations)
            }
        }
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
