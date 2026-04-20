import SwiftUI

struct LocationDetailView: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    @State private var isPresentingEditLocation = false

    var body: some View {
        List {
            Section("Location") {
                LabeledContent("Name", value: location.name)
                LabeledContent("Latitude", value: location.latitude.formatted(.number.precision(.fractionLength(5))))
                LabeledContent("Longitude", value: location.longitude.formatted(.number.precision(.fractionLength(5))))
            }

            Section("Workflows") {
                NavigationLink {
                    PlanView(location: location, aiService: aiService)
                } label: {
                    Label("Plan", systemImage: "sparkles.rectangle.stack")
                }

                NavigationLink {
                    FieldView(location: location)
                } label: {
                    Label("Field", systemImage: "checklist")
                }

                NavigationLink {
                    ReviewView(location: location)
                } label: {
                    Label("Review", systemImage: "photo.on.rectangle")
                }
            }
        }
        .navigationTitle(location.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isPresentingEditLocation = true
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
    }
}
