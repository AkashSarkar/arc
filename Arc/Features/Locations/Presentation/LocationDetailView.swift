import SwiftUI

struct LocationDetailView: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    @State private var isPresentingEditLocation = false

    private var coordinateSummary: String {
        "\(location.latitude.formatted(.number.precision(.fractionLength(4)))), \(location.longitude.formatted(.number.precision(.fractionLength(4))))"
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "camera.aperture",
                    title: location.name,
                    subtitle: "Refine the pin, then move into plan, field, or review.",
                    badges: [
                        ArcHeroBadge(label: coordinateSummary, systemImage: "location.north.line"),
                        ArcHeroBadge(label: location.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    ]
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Location Details") {
                ArcFeatureCard {
                    ArcFeatureTitle(
                        systemImage: "location.circle",
                        title: "Pinned Coordinates",
                        subtitle: "This pin anchors the whole workflow."
                    )

                    LabeledContent("Name", value: location.name)
                    LabeledContent("Latitude", value: location.latitude.formatted(.number.precision(.fractionLength(5))))
                    LabeledContent("Longitude", value: location.longitude.formatted(.number.precision(.fractionLength(5))))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Workflows") {
                NavigationLink {
                    PlanView(location: location, aiService: aiService)
                } label: {
                    WorkflowCard(
                        title: "Plan",
                        subtitle: "Choose timing and generate a shot plan.",
                        systemImage: "sparkles.rectangle.stack",
                        accent: ArcPalette.tint
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    FieldView(location: location)
                } label: {
                    WorkflowCard(
                        title: "Field",
                        subtitle: "Use a high-contrast checklist outdoors.",
                        systemImage: "checklist",
                        accent: ArcPalette.glowPrimary
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    ReviewView(location: location)
                } label: {
                    WorkflowCard(
                        title: "Review",
                        subtitle: "See what you got and what is missing.",
                        systemImage: "photo.on.rectangle",
                        accent: ArcPalette.glowSecondary
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingEditLocation = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit location")
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

private struct WorkflowCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        ArcFeatureCard(accent: accent) {
            ArcFeatureTitle(
                systemImage: systemImage,
                title: title,
                subtitle: subtitle,
                accent: accent
            )
        }
    }
}
